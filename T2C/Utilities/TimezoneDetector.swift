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

    /// Mapping from common timezone abbreviations to IANA identifiers.
    ///
    /// Ambiguity resolution strategy: most-common global interpretation.
    /// Known collisions and resolutions:
    ///   - "IST" → Asia/Kolkata (India Standard Time, UTC+5:30); statistically most common global usage.
    ///             Ireland uses "GMT" in winter and "BST" in summer, making bare "IST" rare for Dublin.
    ///   - "CST" → America/Chicago (Central Standard Time); China Standard Time is less commonly
    ///             written as "CST" — users in China more often write "UTC+8" or "CST+8".
    ///   - "AST" → America/Halifax (Atlantic Standard Time); Arabia Standard Time users typically
    ///             write "AST" less frequently than North American users.
    private static let abbreviationToIANA: [String: String] = [
        // North America
        "PST": "America/Los_Angeles",
        "PDT": "America/Los_Angeles",
        "PT":  "America/Los_Angeles",
        "MST": "America/Denver",
        "MDT": "America/Denver",
        "MT":  "America/Denver",
        "CST": "America/Chicago",
        "CDT": "America/Chicago",
        "CT":  "America/Chicago",
        "EST": "America/New_York",
        "EDT": "America/New_York",
        "ET":  "America/New_York",
        "AST": "America/Halifax",
        "ADT": "America/Halifax",
        "NST": "America/St_Johns",
        "NDT": "America/St_Johns",
        "AKST": "America/Anchorage",
        "AKDT": "America/Anchorage",
        "HST": "Pacific/Honolulu",
        // HDT removed: Hawaii does not observe daylight saving time

        // Europe
        "GMT": "UTC",
        "UTC": "UTC",
        "WET": "Europe/Lisbon",
        "WEST": "Europe/Lisbon",
        "CET": "Europe/Paris",
        "CEST": "Europe/Paris",
        "EET": "Europe/Athens",
        "EEST": "Europe/Athens",
        "BST": "Europe/London",
        "MSK": "Europe/Moscow",

        // Asia / Pacific
        "IST": "Asia/Kolkata",  // India Standard Time (UTC+5:30) — most common global usage
        "JST": "Asia/Tokyo",
        "KST": "Asia/Seoul",
        "HKT": "Asia/Hong_Kong",
        "SGT": "Asia/Singapore",
        "ICT": "Asia/Bangkok",
        "WIB": "Asia/Jakarta",
        "PKT": "Asia/Karachi",
        "NPT": "Asia/Kathmandu",
        "AEST": "Australia/Sydney",
        "AEDT": "Australia/Sydney",
        "ACST": "Australia/Adelaide",
        "ACDT": "Australia/Adelaide",
        "AWST": "Australia/Perth",
        "NZST": "Pacific/Auckland",
        "NZDT": "Pacific/Auckland",
        "CHST": "Pacific/Guam",
        "SST": "Pacific/Pago_Pago",

        // Middle East / Africa
        "IRST": "Asia/Tehran",
        "GST": "Asia/Dubai",
        "EAT": "Africa/Nairobi",
        "WAT": "Africa/Lagos",
        "CAT": "Africa/Harare",
        "SAST": "Africa/Johannesburg",
    ]

    // MARK: - Detection

    /// Detect a timezone reference in the given text.
    /// Returns the matched TimeZone and the abbreviation/offset string that was found.
    static func detect(in text: String) -> (timezone: TimeZone, abbreviation: String)? {
        // 1. Look for UTC/GMT offsets: GMT+9, UTC-5, UTC+05:30, +09:00
        if let result = detectOffset(in: text) {
            return result
        }

        // 2. Look for timezone abbreviations (case-insensitive, whole-word)
        if let result = detectAbbreviation(in: text) {
            return result
        }

        return nil
    }

    // MARK: - Private Helpers

    private static let offsetRegexes: [NSRegularExpression] = {
        let patterns: [String] = [
            #"(?:GMT|UTC)\s*([+-]\d{1,2}(?::\d{2})?)"#,   // GMT+9, UTC+05:30
            #"(?<!\d)([+-]\d{2}:\d{2})(?!\d)"#,              // standalone +09:00
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
    private static let abbreviationRegexes: [(abbreviation: String, ianaID: String, regex: NSRegularExpression)] = {
        abbreviationToIANA
            .keys
            .sorted { $0.count > $1.count }  // longer first to avoid prefix shadowing
            .compactMap { abbr -> (String, String, NSRegularExpression)? in
                let pattern = #"(?<![A-Za-z])"# + NSRegularExpression.escapedPattern(for: abbr) + #"(?![A-Za-z])"#
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
                return (abbr, abbreviationToIANA[abbr]!, regex)
            }
    }()

    private static func detectAbbreviation(in text: String) -> (timezone: TimeZone, abbreviation: String)? {
        let range = NSRange(text.startIndex..., in: text)

        for (abbr, ianaID, regex) in abbreviationRegexes {
            guard regex.firstMatch(in: text, range: range) != nil else { continue }
            if let tz = TimeZone(identifier: ianaID) {
                logger.debug("detectAbbreviation: found '\(abbr)' → \(ianaID)")
                return (tz, abbr.uppercased())
            }
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
