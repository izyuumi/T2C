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

    /// Mapping from common timezone abbreviations to IANA identifiers
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
        "HDT": "Pacific/Honolulu",

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
        "IST": "Europe/Dublin",
        "MSK": "Europe/Moscow",

        // Asia / Pacific
        "JST": "Asia/Tokyo",
        "KST": "Asia/Seoul",
        "CST_CHINA": "Asia/Shanghai",  // ambiguous; handled below
        "HKT": "Asia/Hong_Kong",
        "SGT": "Asia/Singapore",
        "ICT": "Asia/Bangkok",
        "WIB": "Asia/Jakarta",
        "IST_INDIA": "Asia/Kolkata",  // ambiguous; handled below
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
        "AST_ARABIA": "Asia/Riyadh",
        "IRST": "Asia/Tehran",
        "GST": "Asia/Dubai",
        "IST_ISRAEL": "Asia/Jerusalem",
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

    private static func detectOffset(in text: String) -> (timezone: TimeZone, abbreviation: String)? {
        // Patterns: GMT+9, UTC+9, GMT-5, UTC-05:30, +09:00, -05:00
        let patterns: [(String, Bool)] = [
            (#"(?:GMT|UTC)\s*([+-]\d{1,2}(?::\d{2})?)"#, true),   // GMT+9, UTC+05:30
            (#"\b([+-]\d{2}:\d{2})\b"#, false),                     // standalone +09:00
        ]

        for (pattern, hasPrefix) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range) else { continue }

            let fullRange = Range(match.range, in: text)!
            let fullMatch = String(text[fullRange])

            let offsetGroupIndex = hasPrefix ? 1 : 0
            guard match.numberOfRanges > offsetGroupIndex,
                  let offsetRange = Range(match.range(at: hasPrefix ? 1 : 0), in: text) else { continue }
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
        guard let hours = Int(parts[0]) else { return nil }
        let minutes = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        var seconds = hours * 3600 + minutes * 60
        if sign == "-" { seconds = -seconds }

        return TimeZone(secondsFromGMT: seconds)
    }

    private static func detectAbbreviation(in text: String) -> (timezone: TimeZone, abbreviation: String)? {
        // Priority ordered list — try longer ones first to avoid partial matches
        let candidates = abbreviationToIANA.keys.sorted { $0.count > $1.count }

        for abbr in candidates {
            // Match as whole word (not part of a larger identifier)
            let pattern = #"(?<![A-Za-z])"# + NSRegularExpression.escapedPattern(for: abbr) + #"(?![A-Za-z])"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard regex.firstMatch(in: text, range: range) != nil else { continue }

            // Resolve IANA identifier
            let ianaID = abbreviationToIANA[abbr]!
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
