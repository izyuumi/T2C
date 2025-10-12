//
//  MainViewModel.swift
//  T2C
//
//  State machine and orchestration for text-to-calendar conversion
//

import Foundation
import SwiftUI
import OSLog
import Combine

private let logger = Logger(subsystem: "com.t2c.app", category: "MainViewModel")

@MainActor
final class MainViewModel: ObservableObject {

    // MARK: - UI State

    enum UIState: Equatable {
        case idle
        case parsing
        case preview(CalendarEvent)
        case saving
        case saved(CalendarEvent)
        case error(String)
    }

    // MARK: - Published Properties

    @Published var text: String = ""
    @Published var state: UIState = .idle

    // MARK: - Dependencies

    private let parser = NLParser()
    private let calendar = CalendarService()

    // MARK: - Timeout Configuration

    private let parseTimeout: TimeInterval = 30.0  // 30 seconds for LLM parsing
    private let saveTimeout: TimeInterval = 10.0   // 10 seconds for calendar save

    // MARK: - Public Methods

    /// Parse the input text into a calendar event
    func parse() async {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)

        guard !trimmedText.isEmpty else {
            logger.debug("parse: empty text, ignoring")
            return
        }

        logger.info("parse: starting for text='\(trimmedText)'")
        state = .parsing

        do {
            var event = try await withTimeout(parseTimeout) {
                try await self.parser.parse(trimmedText, tz: .current)
            }

            // Apply default duration if end is nil
            event.end = event.end ?? event.start.addingTimeInterval(DateUtil.defaultDuration)

            logger.info("parse: success, transitioning to preview state")
            state = .preview(event)

        } catch {
            logger.error("parse: failed with error=\(error.localizedDescription)")

            let errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't understand that. Try adding a time or date."

            state = .error(errorMessage)
        }
    }

    /// Save the previewed event to the calendar
    func save() async {
        guard case let .preview(event) = state else {
            logger.warning("save: called but not in preview state")
            return
        }

        logger.info("save: starting for event title='\(event.title)'")
        state = .saving

        do {
            try await withTimeout(saveTimeout) {
                // Request calendar permission if needed
                try await self.calendar.requestWriteOnlyIfNeeded()

                // Save the event
                try self.calendar.add(event)
            }

            logger.info("save: success, transitioning to saved state")
            state = .saved(event)

        } catch {
            logger.error("save: failed with error=\(error.localizedDescription)")

            let errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't save to Calendar."

            state = .error(errorMessage)
        }
    }

    /// Reset to idle state
    func reset() {
        logger.debug("reset: returning to idle state")
        text = ""
        state = .idle
    }

    // MARK: - Private Helpers

    /// Executes an async operation with a timeout
    private func withTimeout<T>(
        _ timeout: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Start the operation
            group.addTask {
                try await operation()
            }

            // Start the timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError.operationTimedOut
            }

            // Return the first result (either success or timeout)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Timeout Error

enum TimeoutError: LocalizedError {
    case operationTimedOut

    var errorDescription: String? {
        "Operation timed out. Please try again."
    }
}
