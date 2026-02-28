//
//  TimezoneDetector.swift
//  T2C
//
//  Detects timezone references in natural language text and maps them to TimeZone values.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.t2c.app", category: "TimezoneDetector")

/// Detects timezone abbreviations and UTC offsets from natural language text
enum TimezoneDetector {

    // MARK: - Abbreviation Map

    /// Mapping from common timezone abbreviations to fixed UTC offsets.
    ///
    /// These abbreviations encode a specific offset, so using a regional IANA zone can
    /// silently shift the offset based on the current date's DST rules.
    private static let abbreviationToFixedOffset: [String: Int] = [
        // North America
        "PST": -8 * 3600,
        "PDT": -7 * 3600,
        "MST": -7 * 3600,
        "MDT": -6 * 3600,
        "CST": -6 * 3600,
        "CDT": -5 * 3600,
        "EST": -5 * 3600,
        "EDT": -4 * 3600,
        "AST": -4 * 3600,
        "ADT": -3 * 3600,
        "NST": -(3 * 3600 + 30 * 60),
        "NDT": -(2 * 3600 + 30 * 60),
        "AKST": -9 * 3600,
        "AKDT": -8 * 3600,
        "HST": -10 * 3600,

        // Europe
        "GMT": 0,
        "UTC": 0,
        "WET": 0,
        "WEST": 1 * 3600,
        "CET": 1 * 3600,
        "CEST": 2 * 3600,
        "EET": 2 * 3600,
        "EEST": 3 * 3600,
        "BST": 1 * 3600,
        "MSK": 3 * 3600,

        // Asia / Pacific
        "IST": 5 * 3600 + 30 * 60,  // India Standard Time (UTC+5:30) — most common global usage
        "JST": 9 * 3600,
        "KST": 9 * 3600,
        "HKT": 8 * 3600,
        "SGT": 8 * 3600,
        "ICT": 7 * 3600,
        "WIB": 7 * 3600,
        "PKT": 5 * 3600,
        "NPT": 5 * 3600 + 45 * 60,
        "AEST": 10 * 3600,
        "AEDT": 11 * 3600,
        "ACST": 9 * 3600 + 30 * 60,
        "ACDT": 10 * 3600 + 30 * 60,
        "AWST": 8 * 3600,
        "NZST": 12 * 3600,
        "NZDT": 13 * 3600,
        "CHST": 10 * 3600,
        "SST": -11 * 3600,

        // Middle East / Africa
        "IRST": 3 * 3600 + 30 * 60,
        "GST": 4 * 3600,
        "EAT": 3 * 3600,
        "WAT": 1 * 3600,
        "CAT": 2 * 3600,
        "SAST": 2 * 3600,
    ]

    /// Mapping from regional timezone labels to IANA identifiers.
    ///
    /// These labels describe a locale-specific timezone family rather than a fixed offset,
    /// so preserving the region's DST rules is the correct behavior.
    private static let abbreviationToIANA: [String: String] = [
        // North America
        "PT":  "America/Los_Angeles",
        "MT":  "America/Denver",
        "CT":  "America/Chicago",
        "ET":  "America/New_York",
        // HDT removed: Hawaii does not observe daylight saving time
    ]

    // MARK: - Detection

    /// Detect a timezone reference in the given text.
    /// Returns the matched TimeZone and the abbreviation/offset string that was found.
    static func detect(in text: String) -> (timezone: TimeZone, abbreviation: String)? {
        // 1. Look for UTC/GMT offsets: GMT+9, UTC-5, UTC+05:30, +09:00
        if let result = detectOffset(in: text) {
            return result
        }

        // 2. Look for timezone abbreviations (whole-word, uppercase only)
        if let result = detectAbbreviation(in: text) {
            return result
        }

        return nil
    }

    // MARK: - Private Helpers

    private static let offsetRegexes: [NSRegularExpression] = {
        let patterns: [String] = [
            #"(?:GMT|UTC)\s*([+-]\d{1,2}(?::\d{2})?)"#,   // GMT+9, UTC+05:30
            #"(?<![\d:])([+-]\d{2}:\d{2})(?!\d)"#,              // standalone +09:00
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private static func detectOffset(in text: String) -> (timezone: TimeZone, abbreviation: String)? {
        for regex in offsetRegexes {
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range) else { continue }

            guard let fullRange = Range(match.range, in: text) else { continue }
            let fullMatch = String(text[fullRange])

            // Both patterns use capture group 1 for the offset value
            guard match.numberOfRanges > 1,
                  let offsetRange = Range(match.range(at: 1), in: text) else { continue }
            let offsetStr = String(text[offsetRange])

            if let tz = parseOffsetString(offsetStr) {
                logger.debug("detectOffset: found '\(fullMatch)' → secondsFromGMT=\(tz.secondsFromGMT())")
                return (tz, fullMatch)
            }
        }
        return nil
    }

    private static func parseOffsetString(_ offset: String) -> TimeZone? {
        // offset may be: +9, -5, +09:30, -05:00
        let cleaned = offset.replacingOccurrences(of: " ", with: "")
        guard let sign = cleaned.first, sign == "+" || sign == "-" else { return nil }

        let body = String(cleaned.dropFirst())
        let parts = body.split(separator: ":")
        guard let firstPart = parts.first, let hours = Int(firstPart) else { return nil }
        let minutes = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        var seconds = hours * 3600 + minutes * 60
        if sign == "-" { seconds = -seconds }

        return TimeZone(secondsFromGMT: seconds)
    }

    /// Pre-compiled regexes for each abbreviation, keyed by abbreviation (longest-first order).
    /// Built once on first access; eliminates repeated NSRegularExpression compilation per parse call.
    private static let abbreviationRegexes: [(abbreviation: String, regex: NSRegularExpression)] = {
        Set(abbreviationToFixedOffset.keys).union(abbreviationToIANA.keys)
            .sorted { $0.count > $1.count }  // longer first to avoid prefix shadowing
            .compactMap { abbr -> (String, NSRegularExpression)? in
                let pattern = #"(?<![A-Za-z])"# + NSRegularExpression.escapedPattern(for: abbr) + #"(?![A-Za-z])"#
                guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
                return (abbr, regex)
            }
    }()

    private static func detectAbbreviation(in text: String) -> (timezone: TimeZone, abbreviation: String)? {
        let range = NSRange(text.startIndex..., in: text)
        var earliestMatch: (abbreviation: String, range: NSRange)?

        for (abbr, regex) in abbreviationRegexes {
            for match in regex.matches(in: text, range: range) {
                guard let matchRange = Range(match.range, in: text) else { continue }
                let matchedText = String(text[matchRange])
                guard matchedText == matchedText.uppercased() else { continue }

                if let currentEarliest = earliestMatch {
                    let startsEarlier = match.range.location < currentEarliest.range.location
                    let sameStartLonger = match.range.location == currentEarliest.range.location
                        && match.range.length > currentEarliest.range.length
                    if startsEarlier || sameStartLonger {
                        earliestMatch = (abbr, match.range)
                    }
                } else {
                    earliestMatch = (abbr, match.range)
                }
            }
        }

        guard let earliestMatch else {
            return nil
        }

        let abbr = earliestMatch.abbreviation
        if let secondsFromGMT = abbreviationToFixedOffset[abbr],
           let tz = TimeZone(secondsFromGMT: secondsFromGMT) {
            logger.debug("detectAbbreviation: found '\(abbr)' → fixed UTC offset \(secondsFromGMT)")
            return (tz, abbr.uppercased())
        }

        if let ianaID = abbreviationToIANA[abbr],
           let tz = TimeZone(identifier: ianaID) {
            logger.debug("detectAbbreviation: found '\(abbr)' → \(ianaID)")
            return (tz, abbr.uppercased())
        }

        return nil
    }

    // MARK: - Display

    /// Human-readable description of a timezone for the UI.
    static func displayName(for timezone: TimeZone) -> String {
        let seconds = timezone.secondsFromGMT()
        let hours = seconds / 3600
        let minutes = abs(seconds % 3600) / 60
        let sign = seconds >= 0 ? "+" : "-"
        if minutes == 0 {
            return "UTC\(sign)\(abs(hours))"
        } else {
            return String(format: "UTC%@%d:%02d", sign, abs(hours), minutes)
        }
    }
}
