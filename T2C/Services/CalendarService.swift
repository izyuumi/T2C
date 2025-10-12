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

/// Represents a calendar event with required and optional fields
struct CalendarEvent: Codable, Equatable {
    var title: String
    var start: Date
    var end: Date?
    var location: String?
    var notes: String?
}

private let logger = Logger(subsystem: "com.t2c.app", category: "CalendarService")

/// Manages calendar event creation with write-only access
final class CalendarService {

    private let eventStore = EKEventStore()

    /// Request write-only calendar access if needed (iOS 17+)
    func requestWriteOnlyIfNeeded() async throws {
        logger.debug("requestWriteOnlyIfNeeded: checking authorization status")

        let status = EKEventStore.authorizationStatus(for: .event)
        logger.info("requestWriteOnlyIfNeeded: current status=\(String(describing: status))")

        switch status {
        case .notDetermined:
            logger.debug("requestWriteOnlyIfNeeded: requesting write-only access")
            let granted = try await eventStore.requestWriteOnlyAccessToEvents()
            logger.info("requestWriteOnlyIfNeeded: access granted=\(granted)")

            if !granted {
                throw CalendarError.permissionDenied
            }

        case .restricted, .denied:
            logger.error("requestWriteOnlyIfNeeded: permission denied or restricted")
            throw CalendarError.permissionDenied

        case .fullAccess, .writeOnly:
            logger.debug("requestWriteOnlyIfNeeded: already authorized")

        @unknown default:
            logger.warning("requestWriteOnlyIfNeeded: unknown authorization status")
            throw CalendarError.unknownAuthStatus
        }
    }

    /// Add a calendar event to the default calendar
    func add(_ event: CalendarEvent) throws {
        logger.info("add: creating event title='\(event.title)' start=\(event.start)")

        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.startDate = event.start
        ekEvent.endDate = event.end ?? DateUtil.applyDefaultDuration(start: event.start, end: nil)
        ekEvent.location = event.location
        ekEvent.notes = event.notes
        ekEvent.calendar = eventStore.defaultCalendarForNewEvents

        logger.debug("add: saving to calendar=\(String(describing: ekEvent.calendar?.title))")

        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            logger.info("add: successfully saved event with ID=\(ekEvent.eventIdentifier ?? "unknown")")
        } catch {
            logger.error("add: failed to save event: \(error.localizedDescription)")
            throw CalendarError.saveFailed(error)
        }
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case permissionDenied
    case unknownAuthStatus
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Calendar access denied. Please enable in Settings."
        case .unknownAuthStatus:
            return "Unable to determine calendar access status."
        case .saveFailed(let error):
            return "Failed to save event: \(error.localizedDescription)"
        }
    }
}
