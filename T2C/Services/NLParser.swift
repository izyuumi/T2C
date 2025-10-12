//
//  NLParser.swift
//  T2C
//
//  Natural language parsing using FoundationModels guided generation
//

import Foundation
import FoundationModels
import OSLog

private let logger = Logger(subsystem: "com.t2c.app", category: "NLParser")

// MARK: - Generated Event Structure

/// Intermediate structure for model-generated calendar events with ISO-8601 dates
@Generable
struct ParsedEvent {
    @Guide(description: "The title of the calendar event")
    let title: String

    @Guide(description: "Start date/time in ISO-8601 format with timezone (e.g., 2025-10-12T14:00:00+09:00)")
    let start: String

    @Guide(description: "End date/time in ISO-8601 format with timezone (optional)")
    let end: String?

    @Guide(description: "Event location or venue (optional)")
    let location: String?

    @Guide(description: "Additional notes or description (optional)")
    let notes: String?
}

// MARK: - Parser

/// Parses natural language text into structured calendar events
final class NLParser {

    private let session: LanguageModelSession

    init() {
        // Create session with system prompt for calendar parsing
        self.session = LanguageModelSession {
            """
            You are a calendar event parser. Parse natural language text into structured calendar events.
            Always use ISO-8601 format with timezone for dates (e.g., 2025-10-12T14:00:00+09:00).

            Date interpretation:
            - You will be given the current date/time and timezone in each request
            - If only a time is given, assume the next occurrence of that time from the current date
            - If no end time is given, leave it empty (a default duration will be applied)
            - Interpret relative dates (tomorrow, next week, etc.) based on the current date provided

            Field extraction rules:
            - title: The main event name (concise, typically 2-5 words)
            - location: Physical or virtual location ONLY if explicitly mentioned (leave empty otherwise)
            - notes: All additional context, details, participants, or description provided by user

            Distribute information appropriately: don't dump everything into title, and don't leave out details.
            Capture all user-provided information across the appropriate fields.
            """
        }
    }

    /// Parse natural language text into a CalendarEvent
    func parse(_ text: String, tz timezone: TimeZone = .current) async throws -> CalendarEvent {
        logger.info("parse: input='\(text)' timezone=\(timezone.identifier)")

        // Build prompt with context
        let todayISO = DateUtil.toISO8601(Date(), timezone: timezone)
        let prompt = """
        Parse this natural language text into a calendar event:
        "\(text)"

        Context:
        - Current timezone: \(timezone.identifier)
        - Today's date/time: \(todayISO)
        """

        logger.debug("parse: sending request to model")

        // Generate structured output
        let response = try await session.respond(to: prompt, generating: ParsedEvent.self)
        let parsed = response.content

        logger.debug("parse: received parsed event: \(String(describing: parsed))")

        // Validate and convert to CalendarEvent
        guard let start = DateUtil.parseISO8601(parsed.start, in: timezone) else {
            logger.error("parse: Failed to parse start date: \(parsed.start)")
            throw ParsingError.invalidDateFormat
        }

        let end = parsed.end.flatMap { DateUtil.parseISO8601($0, in: timezone) }

        let event = CalendarEvent(
            title: parsed.title,
            start: start,
            end: end,
            location: parsed.location,
            notes: parsed.notes
        )

        logger.info("parse: successfully parsed event: title=\(parsed.title) start=\(start)")

        return event
    }
}

// MARK: - Errors

enum ParsingError: LocalizedError {
    case invalidDateFormat

    var errorDescription: String? {
        switch self {
        case .invalidDateFormat:
            return "Could not understand the date format. Try being more specific."
        }
    }
}
