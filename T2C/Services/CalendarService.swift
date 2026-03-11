//
//  CalendarService.swift
//  T2C
//
//  EventKit write-only calendar access
//

import Foundation
import EventKit
import OSLog

// MARK: - Calendar Event Model

/// Recurrence rule for repeating calendar events
struct RecurrenceRule: Codable, Equatable {
    enum Frequency: String, Codable, CaseIterable {
        case daily, weekly, monthly, yearly
    }

    var frequency: Frequency
    var interval: Int = 1      // every 1 week, every 2 days, etc.
    var endDate: Date? = nil   // optional end date for recurrence
    var count: Int? = nil      // optional occurrence count ("10 times")
    var daysOfWeek: [Int]? = nil  // EKWeekday values: 1=Sun,2=Mon,3=Tue,4=Wed,5=Thu,6=Fri,7=Sat

    var sanitizedInterval: Int {
        max(interval, 1)
    }

    var sanitizedCount: Int? {
        guard let count, count > 0 else { return nil }
        return count
    }

    var sanitizedDaysOfWeek: [Int]? {
        guard frequency == .weekly else { return nil }

        var seenDays = Set<Int>()
        let validDays = (daysOfWeek ?? []).filter { day in
            guard (1...7).contains(day), !seenDays.contains(day) else { return false }
            seenDays.insert(day)
            return true
        }
        return validDays.isEmpty ? nil : validDays
    }
}

/// Represents a calendar event with required and optional fields
struct CalendarEvent: Codable, Equatable {
    var title: String
    var start: Date
    var end: Date?
    var location: String?
    var notes: String?
    var recurrence: RecurrenceRule?
    var selectedCalendarId: String?
    var wasEndTimeInferred: Bool = false  // Track if we applied default duration
}

private let logger = Logger(subsystem: "com.t2c.app", category: "CalendarService")

/// Manages calendar event creation with write-only access
final class CalendarService {

    private let eventStore = EKEventStore()

    /// The identifier of the last saved event (for undo support)
    private(set) var lastSavedEventId: String?

    /// Request write-only calendar access if needed (iOS 17+)
    func requestWriteOnlyIfNeeded() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        logger.info("requestWriteOnlyIfNeeded: current status=\(String(describing: status))")

        switch status {
        case .notDetermined:
            let granted = try await eventStore.requestWriteOnlyAccessToEvents()
            logger.info("requestWriteOnlyIfNeeded: access granted=\(granted)")

            if !granted {
                throw CalendarError.permissionDenied
            }

        case .restricted, .denied:
            logger.error("requestWriteOnlyIfNeeded: permission denied or restricted")
            throw CalendarError.permissionDenied

        case .fullAccess, .writeOnly:
            break

        @unknown default:
            logger.warning("requestWriteOnlyIfNeeded: unknown authorization status")
            throw CalendarError.unknownAuthStatus
        }
    }

    /// Get all available calendars for events
    func getCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }

    /// Get the default calendar
    func getDefaultCalendar() -> EKCalendar? {
        eventStore.defaultCalendarForNewEvents
    }

    /// Add a calendar event to the specified or default calendar
    func add(_ event: CalendarEvent) throws {
        logger.info("add: creating event title='\(event.title)' start=\(event.start), recurrence=\(String(describing: event.recurrence)), selectedCalendarId=\(String(describing: event.selectedCalendarId))")

        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.startDate = event.start
        ekEvent.endDate = event.end ?? DateUtil.applyDefaultDuration(start: event.start, end: nil)
        ekEvent.location = event.location
        ekEvent.notes = event.notes

        // Use selected calendar if provided, otherwise use default
        if let calendarId = event.selectedCalendarId,
           let calendar = eventStore.calendar(withIdentifier: calendarId) {
            ekEvent.calendar = calendar
            logger.info("add: using selected calendar='\(calendar.title)'")
        } else {
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents
            logger.info("add: using default calendar='\(ekEvent.calendar?.title ?? "unknown")'")
        }

        // Apply recurrence rule if provided
        if let recurrence = event.recurrence {
            let frequency: EKRecurrenceFrequency
            switch recurrence.frequency {
            case .daily:
                frequency = .daily
            case .weekly:
                frequency = .weekly
            case .monthly:
                frequency = .monthly
            case .yearly:
                frequency = .yearly
            }

            let recurrenceEnd: EKRecurrenceEnd?
            if let count = recurrence.sanitizedCount {
                recurrenceEnd = EKRecurrenceEnd(occurrenceCount: count)
            } else if let endDate = recurrence.endDate {
                recurrenceEnd = EKRecurrenceEnd(end: endDate)
            } else {
                recurrenceEnd = nil
            }

            let ekDaysOfWeek: [EKRecurrenceDayOfWeek]? = recurrence.sanitizedDaysOfWeek.flatMap { days -> [EKRecurrenceDayOfWeek]? in
                let mapped = days.compactMap { EKWeekday(rawValue: $0).map { EKRecurrenceDayOfWeek($0) } }
                return mapped.isEmpty ? nil : mapped
            }

            let rule = EKRecurrenceRule(
                recurrenceWith: frequency,
                interval: recurrence.sanitizedInterval,
                daysOfTheWeek: ekDaysOfWeek,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: recurrenceEnd
            )
            ekEvent.recurrenceRules = [rule]
            logger.info("add: applied recurrence rule frequency=\(recurrence.frequency.rawValue), interval=\(recurrence.sanitizedInterval), daysOfWeek=\(String(describing: recurrence.sanitizedDaysOfWeek)), count=\(String(describing: recurrence.sanitizedCount)), hasEndDate=\(recurrence.endDate != nil)")
        }

        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            lastSavedEventId = ekEvent.eventIdentifier
            logger.info("add: successfully saved event with ID=\(ekEvent.eventIdentifier ?? "unknown")")
        } catch {
            logger.error("add: failed to save event: \(error.localizedDescription)")
            throw CalendarError.saveFailed(error)
        }
    }

    /// Delete an event by its identifier
    func deleteEvent(identifier: String) throws {
        guard let event = eventStore.event(withIdentifier: identifier) else {
            logger.warning("deleteEvent: event not found with id=\(identifier)")
            throw CalendarError.eventNotFound
        }

        do {
            try eventStore.remove(event, span: .thisEvent)
            logger.info("deleteEvent: successfully removed event \(identifier)")
            lastSavedEventId = nil
        } catch {
            logger.error("deleteEvent: failed to remove event: \(error.localizedDescription)")
            throw CalendarError.deleteFailed(error)
        }
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case permissionDenied
    case unknownAuthStatus
    case saveFailed(Error)
    case eventNotFound
    case deleteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Calendar access denied. Please enable in Settings."
        case .unknownAuthStatus:
            return "Unable to determine calendar access status."
        case .saveFailed(let error):
            return "Failed to save event: \(error.localizedDescription)"
        case .eventNotFound:
            return "Event not found."
        case .deleteFailed(let error):
            return "Failed to delete event: \(error.localizedDescription)"
        }
    }
}
