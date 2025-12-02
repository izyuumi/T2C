//
//  DateUtil.swift
//  T2C
//
//  ISO-8601 date parsing and default duration helpers
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.t2c.app", category: "DateUtil")

enum DateUtil {

    /// Default event duration in seconds (60 minutes)
    static let defaultDuration: TimeInterval = 3600

    /// Parse ISO-8601 string to Date with current timezone
    static func parseISO8601(_ isoString: String, in timezone: TimeZone = .current) -> Date? {
        // Try with fractional seconds first
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.timeZone = timezone
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let result = formatterWithFractional.date(from: isoString) {
            return result
        }

        // Fallback: try without fractional seconds
        let formatterWithoutFractional = ISO8601DateFormatter()
        formatterWithoutFractional.timeZone = timezone
        formatterWithoutFractional.formatOptions = [.withInternetDateTime]

        if let result = formatterWithoutFractional.date(from: isoString) {
            return result
        }

        logger.error("parseISO8601: ✗ all parsing attempts failed for input=\(isoString)")
        return nil
    }

    /// Apply default duration if end date is nil
    static func applyDefaultDuration(start: Date, end: Date?) -> Date {
        return end ?? start.addingTimeInterval(defaultDuration)
    }

    /// Format Date to ISO-8601 string
    static func toISO8601(_ date: Date, timezone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timezone
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return formatter.string(from: date)
    }

    /// Check if a date is in the past
    static func isPast(_ date: Date) -> Bool {
        date < Date()
    }
}
