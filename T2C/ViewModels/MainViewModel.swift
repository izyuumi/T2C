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
            var event = try await parser.parse(trimmedText, tz: .current)

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
            // Request calendar permission if needed
            try await calendar.requestWriteOnlyIfNeeded()

            // Save the event
            try calendar.add(event)

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
}
