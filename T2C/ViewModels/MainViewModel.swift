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
import EventKit

private let logger = Logger(subsystem: "com.t2c.app", category: "MainViewModel")

@MainActor
final class MainViewModel: ObservableObject {

    // MARK: - Error Handling

    /// Partial parse result for error recovery
    struct PartialParseResult: Equatable {
        var title: String?
        var foundDate: Bool
        var foundTime: Bool
    }

    /// Structured error with suggestions
    struct ParseError: Equatable {
        let message: String
        let suggestions: [String]
        let partialResult: PartialParseResult?
    }

    // MARK: - UI State

    enum UIState: Equatable {
        case idle
        case parsing
        case preview(CalendarEvent)
        case saving
        case saved(CalendarEvent)
        case error(ParseError)
    }

    // MARK: - Published Properties

    @Published var text: String = ""
    @Published var state: UIState = .idle
    @Published var availableCalendars: [EKCalendar] = []
    @Published var selectedCalendarId: String?
    @Published var editableEvent: CalendarEvent?

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

            // Apply default duration from settings if end is nil
            if event.end == nil {
                let defaultMinutes = UserDefaults.standard.integer(forKey: "defaultDuration")
                let duration = TimeInterval((defaultMinutes > 0 ? defaultMinutes : 60) * 60)
                event.end = event.start.addingTimeInterval(duration)
                event.wasEndTimeInferred = true
            }

            // Load available calendars and set default
            availableCalendars = calendar.getCalendars()
            selectedCalendarId = calendar.getDefaultCalendar()?.calendarIdentifier

            // Set editable event for preview editing
            editableEvent = event

            logger.info("parse: success, transitioning to preview state")
            state = .preview(event)

        } catch {
            logger.error("parse: failed with error=\(error.localizedDescription)")

            // Create structured error with suggestions
            let parseError = createParseError(from: error, text: trimmedText)
            state = .error(parseError)
        }
    }

    /// Save the previewed event to the calendar
    func save() async {
        guard var event = editableEvent else {
            logger.warning("save: called but no editable event available")
            return
        }

        logger.info("save: starting for event title='\(event.title)'")
        state = .saving

        // Set selected calendar on the event
        event.selectedCalendarId = selectedCalendarId

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

            let parseError = ParseError(
                message: errorMessage,
                suggestions: ["Check calendar permissions in Settings"],
                partialResult: nil
            )

            state = .error(parseError)
        }
    }

    /// Reset to idle state
    func reset() {
        logger.debug("reset: returning to idle state")
        text = ""
        state = .idle
    }

    // MARK: - Private Helpers

    /// Creates a structured ParseError with helpful suggestions based on the error type
    private func createParseError(from error: Error, text: String) -> ParseError {
        var message = String(localized: "error.generic")
        var suggestions: [String] = []
        var partialResult: PartialParseResult?

        // Analyze error type and provide specific suggestions
        if error is TimeoutError {
            message = String(localized: "error.timeout")
            suggestions = [
                String(localized: "suggestion.simpler"),
                String(localized: "suggestion.break_events"),
                String(localized: "suggestion.clear_format")
            ]
            // Extract partial info from text
            partialResult = PartialParseResult(
                title: extractPotentialTitle(from: text),
                foundDate: containsDateKeywords(text),
                foundTime: containsTimePattern(text)
            )

        } else if let parsingError = error as? ParsingError {
            message = parsingError.errorDescription ?? String(localized: "error.date_format")
            suggestions = [
                String(localized: "suggestion.add_date"),
                String(localized: "suggestion.time_format"),
                String(localized: "suggestion.date_format")
            ]
            partialResult = PartialParseResult(
                title: extractPotentialTitle(from: text),
                foundDate: containsDateKeywords(text),
                foundTime: containsTimePattern(text)
            )

        } else {
            // Generic error
            message = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "error.generic")
            suggestions = [
                String(localized: "suggestion.add_time"),
                String(localized: "suggestion.include_date"),
                String(localized: "suggestion.simpler")
            ]
            partialResult = PartialParseResult(
                title: extractPotentialTitle(from: text),
                foundDate: false,
                foundTime: false
            )
        }

        logger.info("createParseError: created error with \(suggestions.count) suggestions")

        return ParseError(
            message: message,
            suggestions: suggestions,
            partialResult: partialResult
        )
    }

    /// Extract potential title from text (first few words)
    private func extractPotentialTitle(from text: String) -> String? {
        let words = text.split(separator: " ").prefix(5)
        guard !words.isEmpty else { return nil }
        return words.joined(separator: " ")
    }

    /// Check if text contains common date keywords (multi-language)
    private func containsDateKeywords(_ text: String) -> Bool {
        // English
        let englishKeywords = ["tomorrow", "today", "next", "this", "monday", "tuesday", "wednesday",
                               "thursday", "friday", "saturday", "sunday", "week", "month"]
        // Japanese
        let japaneseKeywords = ["明日", "今日", "来週", "今週", "月曜", "火曜", "水曜", "木曜", "金曜", "土曜", "日曜"]
        // Chinese
        let chineseKeywords = ["明天", "今天", "下周", "这周", "星期", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        // Korean
        let koreanKeywords = ["내일", "오늘", "다음 주", "이번 주", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일", "일요일"]
        // Spanish
        let spanishKeywords = ["mañana", "hoy", "próximo", "próxima", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
        // French
        let frenchKeywords = ["demain", "aujourd'hui", "prochain", "prochaine", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
        // German
        let germanKeywords = ["morgen", "heute", "nächste", "nächsten", "montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag"]

        let allKeywords = englishKeywords + japaneseKeywords + chineseKeywords + koreanKeywords + spanishKeywords + frenchKeywords + germanKeywords
        let lowercased = text.lowercased()
        return allKeywords.contains { lowercased.contains($0.lowercased()) }
    }

    /// Check if text contains time patterns (multi-language)
    private func containsTimePattern(_ text: String) -> Bool {
        // English/general: 2pm, 14:00, 2:30pm
        let englishPattern = #"\d{1,2}(:\d{2})?\s*(am|pm|AM|PM)?"#
        // Japanese: 14時, 午後2時, 14時30分
        let japanesePattern = #"\d{1,2}時|午前|午後"#
        // Chinese: 14点, 下午2点, 14点30分
        let chinesePattern = #"\d{1,2}点|上午|下午"#
        // Korean: 2시, 오후 2시
        let koreanPattern = #"\d{1,2}시|오전|오후"#

        return text.range(of: englishPattern, options: .regularExpression) != nil ||
               text.range(of: japanesePattern, options: .regularExpression) != nil ||
               text.range(of: chinesePattern, options: .regularExpression) != nil ||
               text.range(of: koreanPattern, options: .regularExpression) != nil
    }

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
