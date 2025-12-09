//
//  DateUtilTests.swift
//  T2CTests
//
//  Comprehensive tests for DateUtil ISO-8601 parsing and date utilities
//

import XCTest
@testable import T2C

final class DateUtilTests: XCTestCase {

    // MARK: - parseISO8601 Tests

    func testParseISO8601WithFractionalSeconds() {
        // Given: ISO-8601 string with fractional seconds
        let isoString = "2025-12-15T14:30:45.123+09:00"

        // When: Parsing the string
        let result = DateUtil.parseISO8601(isoString)

        // Then: Should successfully parse
        XCTAssertNotNil(result, "Should parse ISO-8601 with fractional seconds")

        if let date = result {
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents(in: TimeZone(identifier: "Asia/Tokyo")!, from: date)
            XCTAssertEqual(components.year, 2025)
            XCTAssertEqual(components.month, 12)
            XCTAssertEqual(components.day, 15)
            XCTAssertEqual(components.hour, 14)
            XCTAssertEqual(components.minute, 30)
            XCTAssertEqual(components.second, 45)
        }
    }

    func testParseISO8601WithoutFractionalSeconds() {
        // Given: ISO-8601 string without fractional seconds
        let isoString = "2025-12-15T14:30:45+09:00"

        // When: Parsing the string
        let result = DateUtil.parseISO8601(isoString)

        // Then: Should successfully parse
        XCTAssertNotNil(result, "Should parse ISO-8601 without fractional seconds")

        if let date = result {
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents(in: TimeZone(identifier: "Asia/Tokyo")!, from: date)
            XCTAssertEqual(components.year, 2025)
            XCTAssertEqual(components.month, 12)
            XCTAssertEqual(components.day, 15)
            XCTAssertEqual(components.hour, 14)
            XCTAssertEqual(components.minute, 30)
            XCTAssertEqual(components.second, 45)
        }
    }

    func testParseISO8601WithDifferentTimezones() {
        // Given: ISO-8601 strings with different timezones
        let utcString = "2025-06-20T12:00:00Z"
        let estString = "2025-06-20T12:00:00-05:00"
        let jstString = "2025-06-20T12:00:00+09:00"

        // When: Parsing each string
        let utcDate = DateUtil.parseISO8601(utcString)
        let estDate = DateUtil.parseISO8601(estString)
        let jstDate = DateUtil.parseISO8601(jstString)

        // Then: All should parse successfully
        XCTAssertNotNil(utcDate, "Should parse UTC timezone")
        XCTAssertNotNil(estDate, "Should parse EST timezone")
        XCTAssertNotNil(jstDate, "Should parse JST timezone")

        // UTC noon should be different absolute times
        XCTAssertNotEqual(utcDate, estDate)
        XCTAssertNotEqual(utcDate, jstDate)
        XCTAssertNotEqual(estDate, jstDate)
    }

    func testParseISO8601WithInvalidFormat() {
        // Given: Invalid ISO-8601 strings
        let invalidFormats = [
            "2025-12-15",                    // Missing time
            "14:30:45",                      // Missing date
            "2025/12/15 14:30:45",          // Wrong separators
            "not a date",                    // Completely invalid
            "2025-13-01T14:30:45+09:00",    // Invalid month
            "2025-12-32T14:30:45+09:00"     // Invalid day
        ]

        // When/Then: Each should fail to parse
        for invalidString in invalidFormats {
            let result = DateUtil.parseISO8601(invalidString)
            XCTAssertNil(result, "Should return nil for invalid format: \(invalidString)")
        }
    }

    func testParseISO8601WithCustomTimezone() {
        // Given: ISO-8601 string and custom timezone
        let isoString = "2025-12-15T14:30:45+09:00"
        let customTimezone = TimeZone(identifier: "America/New_York")!

        // When: Parsing with custom timezone
        let result = DateUtil.parseISO8601(isoString, in: customTimezone)

        // Then: Should parse successfully (timezone parameter affects interpretation)
        XCTAssertNotNil(result)
    }

    // MARK: - toISO8601 Tests

    func testToISO8601BasicFormatting() {
        // Given: A known date
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 15
        components.hour = 14
        components.minute = 30
        components.second = 45
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")

        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to create test date")
            return
        }

        // When: Converting to ISO-8601
        let isoString = DateUtil.toISO8601(date, timezone: TimeZone(identifier: "Asia/Tokyo")!)

        // Then: Should format correctly with fractional seconds
        XCTAssertTrue(isoString.contains("2025-12-15T14:30:45"))
        XCTAssertTrue(isoString.contains("+09:00"))
    }

    func testToISO8601RoundTrip() {
        // Given: Original date
        let originalDate = Date()

        // When: Converting to ISO-8601 and back
        let isoString = DateUtil.toISO8601(originalDate)
        guard let parsedDate = DateUtil.parseISO8601(isoString) else {
            XCTFail("Failed to parse ISO-8601 string")
            return
        }

        // Then: Should round-trip successfully (within 1 second due to fractional precision)
        let difference = abs(originalDate.timeIntervalSince(parsedDate))
        XCTAssertLessThan(difference, 1.0, "Round-trip conversion should preserve date within 1 second")
    }

    func testToISO8601WithDifferentTimezones() {
        // Given: Same date but different timezones
        let date = Date()
        let utc = TimeZone(identifier: "UTC")!
        let jst = TimeZone(identifier: "Asia/Tokyo")!
        let est = TimeZone(identifier: "America/New_York")!

        // When: Converting with different timezones
        let utcString = DateUtil.toISO8601(date, timezone: utc)
        let jstString = DateUtil.toISO8601(date, timezone: jst)
        let estString = DateUtil.toISO8601(date, timezone: est)

        // Then: All should contain valid ISO-8601 format with correct timezone offset
        XCTAssertTrue(utcString.contains("Z") || utcString.contains("+00:00"))
        XCTAssertTrue(jstString.contains("+09:00"))
        XCTAssertTrue(estString.contains("-05:00") || estString.contains("-04:00")) // EST/EDT
    }

    // MARK: - applyDefaultDuration Tests

    func testApplyDefaultDurationWithNilEnd() {
        // Given: Start date with nil end date
        let start = Date()

        // When: Applying default duration
        let end = DateUtil.applyDefaultDuration(start: start, end: nil)

        // Then: Should add default duration (3600 seconds = 1 hour)
        let expectedEnd = start.addingTimeInterval(DateUtil.defaultDuration)
        XCTAssertEqual(end.timeIntervalSince1970, expectedEnd.timeIntervalSince1970, accuracy: 0.001)
    }

    func testApplyDefaultDurationWithExistingEnd() {
        // Given: Start date with explicit end date
        let start = Date()
        let explicitEnd = start.addingTimeInterval(7200) // 2 hours

        // When: Applying default duration
        let end = DateUtil.applyDefaultDuration(start: start, end: explicitEnd)

        // Then: Should return the explicit end unchanged
        XCTAssertEqual(end, explicitEnd)
    }

    func testDefaultDurationValue() {
        // Then: Default duration should be 60 minutes (3600 seconds)
        XCTAssertEqual(DateUtil.defaultDuration, 3600)
    }

    // MARK: - isPast Tests

    func testIsPastWithPastDate() {
        // Given: A date in the past
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago

        // When: Checking if it's past
        let result = DateUtil.isPast(pastDate)

        // Then: Should return true
        XCTAssertTrue(result, "Date 1 hour ago should be in the past")
    }

    func testIsPastWithFutureDate() {
        // Given: A date in the future
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now

        // When: Checking if it's past
        let result = DateUtil.isPast(futureDate)

        // Then: Should return false
        XCTAssertFalse(result, "Date 1 hour from now should not be in the past")
    }

    func testIsPastWithCurrentTime() {
        // Given: Current date (approximately)
        let now = Date()

        // When: Checking if it's past (with small delay)
        usleep(10000) // 10ms delay
        let result = DateUtil.isPast(now)

        // Then: Should return true (since we delayed slightly)
        XCTAssertTrue(result, "Date created just before should be in the past")
    }

    // MARK: - Edge Cases

    func testLeapYearFebruary29() {
        // Given: Leap year date (February 29, 2024)
        let isoString = "2024-02-29T12:00:00+00:00"

        // When: Parsing the leap year date
        let result = DateUtil.parseISO8601(isoString)

        // Then: Should parse successfully
        XCTAssertNotNil(result, "Should parse leap year date")

        if let date = result {
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
            XCTAssertEqual(components.month, 2)
            XCTAssertEqual(components.day, 29)
        }
    }

    func testNonLeapYearFebruary29() {
        // Given: Non-leap year February 29 (invalid)
        let isoString = "2025-02-29T12:00:00+00:00"

        // When: Parsing the invalid date
        let result = DateUtil.parseISO8601(isoString)

        // Then: Should fail to parse
        XCTAssertNil(result, "Should not parse February 29 in non-leap year")
    }

    func testTimezoneBoundary() {
        // Given: Date at timezone boundary (midnight in different timezones)
        let utcMidnight = "2025-12-15T00:00:00Z"
        let jstMidnight = "2025-12-15T00:00:00+09:00"

        // When: Parsing both
        guard let utcDate = DateUtil.parseISO8601(utcMidnight),
              let jstDate = DateUtil.parseISO8601(jstMidnight) else {
            XCTFail("Failed to parse timezone boundary dates")
            return
        }

        // Then: JST midnight should be 9 hours before UTC midnight
        let difference = utcDate.timeIntervalSince(jstDate)
        XCTAssertEqual(difference, 9 * 3600, accuracy: 1.0, "Should have 9 hour difference")
    }

    func testDSTTransition() {
        // Given: Dates around DST transition (US Eastern Time)
        // March 10, 2024: DST begins (spring forward)
        let beforeDST = "2024-03-10T01:00:00-05:00" // EST
        let afterDST = "2024-03-10T03:00:00-04:00"  // EDT

        // When: Parsing both dates
        guard let beforeDate = DateUtil.parseISO8601(beforeDST),
              let afterDate = DateUtil.parseISO8601(afterDST) else {
            XCTFail("Failed to parse DST transition dates")
            return
        }

        // Then: Should be 1 hour apart (clock skips 2am)
        let difference = afterDate.timeIntervalSince(beforeDate)
        XCTAssertEqual(difference, 3600, accuracy: 1.0, "DST transition should show 1 hour difference")
    }

    func testYearBoundary() {
        // Given: Dates at year boundaries
        let endOf2024 = "2024-12-31T23:59:59Z"
        let startOf2025 = "2025-01-01T00:00:00Z"

        // When: Parsing both
        guard let endDate = DateUtil.parseISO8601(endOf2024),
              let startDate = DateUtil.parseISO8601(startOf2025) else {
            XCTFail("Failed to parse year boundary dates")
            return
        }

        // Then: Should be 1 second apart
        let difference = startDate.timeIntervalSince(endDate)
        XCTAssertEqual(difference, 1.0, accuracy: 0.1, "Year boundary should be 1 second apart")
    }

    func testMillenniumBoundary() {
        // Given: Y2K boundary
        let endOf1999 = "1999-12-31T23:59:59Z"
        let startOf2000 = "2000-01-01T00:00:00Z"

        // When: Parsing both
        guard let endDate = DateUtil.parseISO8601(endOf1999),
              let startDate = DateUtil.parseISO8601(startOf2000) else {
            XCTFail("Failed to parse millennium boundary dates")
            return
        }

        // Then: Should parse correctly and be 1 second apart
        let difference = startDate.timeIntervalSince(endDate)
        XCTAssertEqual(difference, 1.0, accuracy: 0.1)
    }

    func testExtremelyLongTimespan() {
        // Given: Dates very far apart
        let ancient = "1970-01-01T00:00:00Z" // Unix epoch
        let future = "2099-12-31T23:59:59Z"

        // When: Parsing both
        let ancientDate = DateUtil.parseISO8601(ancient)
        let futureDate = DateUtil.parseISO8601(future)

        // Then: Both should parse successfully
        XCTAssertNotNil(ancientDate, "Should parse Unix epoch")
        XCTAssertNotNil(futureDate, "Should parse far future date")

        if let ancient = ancientDate, let future = futureDate {
            XCTAssertLessThan(ancient, future)
        }
    }
}
