//
//  CalendarServiceTests.swift
//  T2CTests
//
//  Comprehensive tests for CalendarService models (CalendarEvent and RecurrenceRule)
//

import XCTest
@testable import T2C

final class CalendarServiceTests: XCTestCase {

    // MARK: - CalendarEvent Tests

    func testCalendarEventInitialization() {
        // Given: Basic event data
        let title = "Team Meeting"
        let start = Date()
        let end = start.addingTimeInterval(3600)

        // When: Creating a CalendarEvent
        let event = CalendarEvent(
            title: title,
            start: start,
            end: end
        )

        // Then: Properties should be set correctly
        XCTAssertEqual(event.title, title)
        XCTAssertEqual(event.start, start)
        XCTAssertEqual(event.end, end)
        XCTAssertNil(event.location)
        XCTAssertNil(event.notes)
        XCTAssertNil(event.recurrence)
        XCTAssertNil(event.selectedCalendarId)
        XCTAssertFalse(event.wasEndTimeInferred)
    }

    func testCalendarEventInitializationWithAllFields() {
        // Given: Complete event data
        let title = "Project Kickoff"
        let start = Date()
        let end = start.addingTimeInterval(7200)
        let location = "Conference Room A"
        let notes = "Bring laptops and project proposals"
        let recurrence = RecurrenceRule(frequency: .weekly, interval: 1)
        let calendarId = "work-calendar-123"

        // When: Creating a CalendarEvent with all fields
        let event = CalendarEvent(
            title: title,
            start: start,
            end: end,
            location: location,
            notes: notes,
            recurrence: recurrence,
            selectedCalendarId: calendarId,
            wasEndTimeInferred: true
        )

        // Then: All properties should be set correctly
        XCTAssertEqual(event.title, title)
        XCTAssertEqual(event.start, start)
        XCTAssertEqual(event.end, end)
        XCTAssertEqual(event.location, location)
        XCTAssertEqual(event.notes, notes)
        XCTAssertEqual(event.recurrence, recurrence)
        XCTAssertEqual(event.selectedCalendarId, calendarId)
        XCTAssertTrue(event.wasEndTimeInferred)
    }

    func testCalendarEventWithNilEndDate() {
        // Given: Event without end date
        let event = CalendarEvent(
            title: "Open-ended meeting",
            start: Date(),
            end: nil
        )

        // Then: End date should be nil
        XCTAssertNil(event.end)
    }

    func testCalendarEventEquality() {
        // Given: Two identical events
        let start = Date()
        let end = start.addingTimeInterval(3600)

        let event1 = CalendarEvent(
            title: "Meeting",
            start: start,
            end: end,
            location: "Room A",
            notes: "Notes"
        )

        let event2 = CalendarEvent(
            title: "Meeting",
            start: start,
            end: end,
            location: "Room A",
            notes: "Notes"
        )

        // Then: They should be equal
        XCTAssertEqual(event1, event2)
    }

    func testCalendarEventInequality() {
        // Given: Two different events
        let start = Date()

        let event1 = CalendarEvent(title: "Meeting A", start: start, end: nil)
        let event2 = CalendarEvent(title: "Meeting B", start: start, end: nil)

        // Then: They should not be equal
        XCTAssertNotEqual(event1, event2)
    }

    // MARK: - CalendarEvent Encoding/Decoding Tests

    func testCalendarEventEncodingDecoding() throws {
        // Given: A calendar event
        let start = Date()
        let end = start.addingTimeInterval(3600)

        let originalEvent = CalendarEvent(
            title: "Encoded Meeting",
            start: start,
            end: end,
            location: "Virtual",
            notes: "Test encoding"
        )

        // When: Encoding and then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEvent)

        let decoder = JSONDecoder()
        let decodedEvent = try decoder.decode(CalendarEvent.self, from: data)

        // Then: Should match original
        XCTAssertEqual(decodedEvent.title, originalEvent.title)
        XCTAssertEqual(decodedEvent.start.timeIntervalSince1970,
                      originalEvent.start.timeIntervalSince1970,
                      accuracy: 0.001)
        XCTAssertEqual(decodedEvent.end?.timeIntervalSince1970,
                      originalEvent.end?.timeIntervalSince1970,
                      accuracy: 0.001)
        XCTAssertEqual(decodedEvent.location, originalEvent.location)
        XCTAssertEqual(decodedEvent.notes, originalEvent.notes)
    }

    func testCalendarEventEncodingDecodingWithRecurrence() throws {
        // Given: Event with recurrence
        let recurrence = RecurrenceRule(
            frequency: .weekly,
            interval: 2,
            endDate: Date().addingTimeInterval(86400 * 30)
        )

        let originalEvent = CalendarEvent(
            title: "Recurring Meeting",
            start: Date(),
            end: nil,
            recurrence: recurrence
        )

        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEvent)

        let decoder = JSONDecoder()
        let decodedEvent = try decoder.decode(CalendarEvent.self, from: data)

        // Then: Recurrence should be preserved
        XCTAssertEqual(decodedEvent.recurrence, originalEvent.recurrence)
        XCTAssertEqual(decodedEvent.recurrence?.frequency, .weekly)
        XCTAssertEqual(decodedEvent.recurrence?.interval, 2)
    }

    func testCalendarEventEncodingDecodingWithWasEndTimeInferred() throws {
        // Given: Event with inferred end time flag
        let event = CalendarEvent(
            title: "Inferred End",
            start: Date(),
            end: Date().addingTimeInterval(3600),
            wasEndTimeInferred: true
        )

        // When: Encoding and decoding
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(CalendarEvent.self, from: data)

        // Then: Flag should be preserved
        XCTAssertTrue(decoded.wasEndTimeInferred)
    }

    func testCalendarEventEncodingDecodingWithSelectedCalendar() throws {
        // Given: Event with selected calendar
        let event = CalendarEvent(
            title: "Work Event",
            start: Date(),
            end: nil,
            selectedCalendarId: "calendar-456"
        )

        // When: Encoding and decoding
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(CalendarEvent.self, from: data)

        // Then: Calendar ID should be preserved
        XCTAssertEqual(decoded.selectedCalendarId, "calendar-456")
    }

    // MARK: - RecurrenceRule Tests

    func testRecurrenceRuleInitializationDaily() {
        // Given: Daily recurrence
        let rule = RecurrenceRule(frequency: .daily)

        // Then: Should have default values
        XCTAssertEqual(rule.frequency, .daily)
        XCTAssertEqual(rule.interval, 1)
        XCTAssertNil(rule.endDate)
    }

    func testRecurrenceRuleInitializationWeekly() {
        // Given: Weekly recurrence with interval
        let rule = RecurrenceRule(frequency: .weekly, interval: 2)

        // Then: Should have specified interval
        XCTAssertEqual(rule.frequency, .weekly)
        XCTAssertEqual(rule.interval, 2)
        XCTAssertNil(rule.endDate)
    }

    func testRecurrenceRuleInitializationWithEndDate() {
        // Given: Recurrence with end date
        let endDate = Date().addingTimeInterval(86400 * 60) // 60 days

        let rule = RecurrenceRule(
            frequency: .monthly,
            interval: 1,
            endDate: endDate
        )

        // Then: Should have end date
        XCTAssertEqual(rule.frequency, .monthly)
        XCTAssertEqual(rule.interval, 1)
        XCTAssertEqual(rule.endDate, endDate)
    }

    func testRecurrenceRuleEquality() {
        // Given: Two identical recurrence rules
        let endDate = Date()

        let rule1 = RecurrenceRule(
            frequency: .weekly,
            interval: 2,
            endDate: endDate
        )

        let rule2 = RecurrenceRule(
            frequency: .weekly,
            interval: 2,
            endDate: endDate
        )

        // Then: Should be equal
        XCTAssertEqual(rule1, rule2)
    }

    func testRecurrenceRuleInequalityDifferentFrequency() {
        // Given: Rules with different frequencies
        let rule1 = RecurrenceRule(frequency: .daily)
        let rule2 = RecurrenceRule(frequency: .weekly)

        // Then: Should not be equal
        XCTAssertNotEqual(rule1, rule2)
    }

    func testRecurrenceRuleInequalityDifferentInterval() {
        // Given: Rules with different intervals
        let rule1 = RecurrenceRule(frequency: .weekly, interval: 1)
        let rule2 = RecurrenceRule(frequency: .weekly, interval: 2)

        // Then: Should not be equal
        XCTAssertNotEqual(rule1, rule2)
    }

    func testRecurrenceRuleInequalityDifferentEndDate() {
        // Given: Rules with different end dates
        let endDate1 = Date()
        let endDate2 = Date().addingTimeInterval(86400)

        let rule1 = RecurrenceRule(frequency: .daily, endDate: endDate1)
        let rule2 = RecurrenceRule(frequency: .daily, endDate: endDate2)

        // Then: Should not be equal
        XCTAssertNotEqual(rule1, rule2)
    }

    // MARK: - RecurrenceRule Encoding/Decoding Tests

    func testRecurrenceRuleEncodingDecoding() throws {
        // Given: A recurrence rule
        let endDate = Date().addingTimeInterval(86400 * 30)

        let originalRule = RecurrenceRule(
            frequency: .monthly,
            interval: 3,
            endDate: endDate
        )

        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalRule)

        let decoder = JSONDecoder()
        let decodedRule = try decoder.decode(RecurrenceRule.self, from: data)

        // Then: Should match original
        XCTAssertEqual(decodedRule.frequency, originalRule.frequency)
        XCTAssertEqual(decodedRule.interval, originalRule.interval)
        XCTAssertEqual(decodedRule.endDate?.timeIntervalSince1970,
                      originalRule.endDate?.timeIntervalSince1970,
                      accuracy: 0.001)
    }

    func testRecurrenceRuleEncodingDecodingWithoutEndDate() throws {
        // Given: Rule without end date
        let rule = RecurrenceRule(frequency: .yearly, interval: 1)

        // When: Encoding and decoding
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(RecurrenceRule.self, from: data)

        // Then: Should match original
        XCTAssertEqual(decoded.frequency, .yearly)
        XCTAssertEqual(decoded.interval, 1)
        XCTAssertNil(decoded.endDate)
    }

    // MARK: - RecurrenceRule.Frequency Tests

    func testRecurrenceFrequencyRawValues() {
        // Then: Raw values should match expected strings
        XCTAssertEqual(RecurrenceRule.Frequency.daily.rawValue, "daily")
        XCTAssertEqual(RecurrenceRule.Frequency.weekly.rawValue, "weekly")
        XCTAssertEqual(RecurrenceRule.Frequency.monthly.rawValue, "monthly")
        XCTAssertEqual(RecurrenceRule.Frequency.yearly.rawValue, "yearly")
    }

    func testRecurrenceFrequencyInitFromRawValue() {
        // When: Initializing from raw values
        let daily = RecurrenceRule.Frequency(rawValue: "daily")
        let weekly = RecurrenceRule.Frequency(rawValue: "weekly")
        let monthly = RecurrenceRule.Frequency(rawValue: "monthly")
        let yearly = RecurrenceRule.Frequency(rawValue: "yearly")
        let invalid = RecurrenceRule.Frequency(rawValue: "invalid")

        // Then: Should initialize correctly
        XCTAssertEqual(daily, .daily)
        XCTAssertEqual(weekly, .weekly)
        XCTAssertEqual(monthly, .monthly)
        XCTAssertEqual(yearly, .yearly)
        XCTAssertNil(invalid)
    }

    func testRecurrenceFrequencyCaseIterable() {
        // When: Accessing all cases
        let allCases = RecurrenceRule.Frequency.allCases

        // Then: Should have all 4 frequencies
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.daily))
        XCTAssertTrue(allCases.contains(.weekly))
        XCTAssertTrue(allCases.contains(.monthly))
        XCTAssertTrue(allCases.contains(.yearly))
    }

    func testRecurrenceFrequencyEncoding() throws {
        // Given: Each frequency
        let frequencies: [RecurrenceRule.Frequency] = [.daily, .weekly, .monthly, .yearly]

        for frequency in frequencies {
            // When: Encoding
            let data = try JSONEncoder().encode(frequency)
            let decoded = try JSONDecoder().decode(RecurrenceRule.Frequency.self, from: data)

            // Then: Should round-trip correctly
            XCTAssertEqual(decoded, frequency)
        }
    }

    // MARK: - CalendarError Tests

    func testCalendarErrorPermissionDeniedDescription() {
        // Given: Permission denied error
        let error = CalendarError.permissionDenied

        // Then: Should have helpful description
        XCTAssertEqual(error.errorDescription,
                      "Calendar access denied. Please enable in Settings.")
    }

    func testCalendarErrorUnknownAuthStatusDescription() {
        // Given: Unknown auth status error
        let error = CalendarError.unknownAuthStatus

        // Then: Should have helpful description
        XCTAssertEqual(error.errorDescription,
                      "Unable to determine calendar access status.")
    }

    func testCalendarErrorSaveFailedDescription() {
        // Given: Save failed error with underlying error
        struct UnderlyingError: Error, LocalizedError {
            var errorDescription: String? { "Disk full" }
        }

        let error = CalendarError.saveFailed(UnderlyingError())

        // Then: Should include underlying error description
        XCTAssertTrue(error.errorDescription?.contains("Failed to save event") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Disk full") ?? false)
    }

    // MARK: - Edge Cases and Integration Tests

    func testCalendarEventMutability() {
        // Given: A calendar event
        var event = CalendarEvent(
            title: "Original",
            start: Date(),
            end: nil
        )

        // When: Modifying properties
        event.title = "Modified"
        event.location = "New Location"
        event.notes = "New notes"
        event.wasEndTimeInferred = true

        // Then: Should be mutable
        XCTAssertEqual(event.title, "Modified")
        XCTAssertEqual(event.location, "New Location")
        XCTAssertEqual(event.notes, "New notes")
        XCTAssertTrue(event.wasEndTimeInferred)
    }

    func testRecurrenceRuleMutability() {
        // Given: A recurrence rule
        var rule = RecurrenceRule(frequency: .daily)

        // When: Modifying properties
        rule.frequency = .weekly
        rule.interval = 3
        rule.endDate = Date()

        // Then: Should be mutable
        XCTAssertEqual(rule.frequency, .weekly)
        XCTAssertEqual(rule.interval, 3)
        XCTAssertNotNil(rule.endDate)
    }

    func testComplexCalendarEventWithRecurrence() {
        // Given: Complex event with recurrence
        let recurrence = RecurrenceRule(
            frequency: .weekly,
            interval: 2,
            endDate: Date().addingTimeInterval(86400 * 90)
        )

        let event = CalendarEvent(
            title: "Bi-weekly Team Sync",
            start: Date(),
            end: Date().addingTimeInterval(1800), // 30 minutes
            location: "Zoom",
            notes: "Recurring team standup every 2 weeks for 90 days",
            recurrence: recurrence,
            selectedCalendarId: "team-calendar",
            wasEndTimeInferred: false
        )

        // Then: All properties should be set correctly
        XCTAssertEqual(event.title, "Bi-weekly Team Sync")
        XCTAssertNotNil(event.end)
        XCTAssertEqual(event.location, "Zoom")
        XCTAssertNotNil(event.notes)
        XCTAssertEqual(event.recurrence?.frequency, .weekly)
        XCTAssertEqual(event.recurrence?.interval, 2)
        XCTAssertNotNil(event.recurrence?.endDate)
        XCTAssertEqual(event.selectedCalendarId, "team-calendar")
        XCTAssertFalse(event.wasEndTimeInferred)
    }

    func testJSONEncodingReadability() throws {
        // Given: A calendar event
        let event = CalendarEvent(
            title: "Test Event",
            start: Date(),
            end: nil,
            location: "Office",
            notes: "Test notes"
        )

        // When: Encoding to pretty-printed JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(event)
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Then: JSON should be readable and contain expected fields
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString?.contains("title") ?? false)
        XCTAssertTrue(jsonString?.contains("Test Event") ?? false)
        XCTAssertTrue(jsonString?.contains("location") ?? false)
        XCTAssertTrue(jsonString?.contains("Office") ?? false)
    }

    func testRecurrenceRuleIntervals() {
        // Given: Various recurrence intervals
        let intervals = [1, 2, 3, 7, 14, 30]

        for interval in intervals {
            // When: Creating rule with interval
            let rule = RecurrenceRule(frequency: .daily, interval: interval)

            // Then: Should store interval correctly
            XCTAssertEqual(rule.interval, interval)
        }
    }

    func testAllRecurrenceFrequenciesInEvents() throws {
        // Given: Events with all frequency types
        let frequencies: [RecurrenceRule.Frequency] = [.daily, .weekly, .monthly, .yearly]

        for frequency in frequencies {
            // When: Creating event with this frequency
            let rule = RecurrenceRule(frequency: frequency)
            let event = CalendarEvent(
                title: "Event",
                start: Date(),
                end: nil,
                recurrence: rule
            )

            // Then: Should encode/decode correctly
            let data = try JSONEncoder().encode(event)
            let decoded = try JSONDecoder().decode(CalendarEvent.self, from: data)

            XCTAssertEqual(decoded.recurrence?.frequency, frequency)
        }
    }
}
