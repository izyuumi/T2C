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

    @Guide(description: "Recurrence frequency if this is a repeating event: daily, weekly, monthly, or yearly (optional)")
    let recurrenceFrequency: String?

    @Guide(description: "Recurrence interval - how often the event repeats, e.g., 1 for every week, 2 for every 2 weeks (optional, defaults to 1)")
    let recurrenceInterval: Int?

    @Guide(description: "End date for recurrence in ISO-8601 format (optional)")
    let recurrenceEndDate: String?
}

// MARK: - Parser

/// Parses natural language text into structured calendar events
final class NLParser {

    private let session: LanguageModelSession

    init() {
        // Create session with system prompt for calendar parsing (multi-language)
        self.session = LanguageModelSession {
            """
            You are a multilingual calendar event parser. Parse natural language text into structured calendar events.
            You understand English, Japanese (日本語), Chinese (中文), Korean (한국어), Spanish (Español), French (Français), and German (Deutsch).
            Always use ISO-8601 format with timezone for dates (e.g., 2025-10-12T14:00:00+09:00).
            IMPORTANT: Output the title in the SAME LANGUAGE as the input text.

            Date interpretation (all languages):
            - You will be given the current date/time and timezone in each request
            - If only a time is given, assume the next occurrence of that time from the current date
            - If no end time is given, leave it empty (a default duration will be applied)
            - Interpret relative dates based on the current date provided

            Language-specific date/time patterns:

            Japanese (日本語):
            - 明日 (ashita) = tomorrow, 今日 (kyō) = today, 来週 (raishū) = next week
            - 月曜日 (getsuyōbi) = Monday, 火曜日 = Tuesday, 水曜日 = Wednesday, 木曜日 = Thursday, 金曜日 = Friday, 土曜日 = Saturday, 日曜日 = Sunday
            - 午前 (gozen) = AM, 午後 (gogo) = PM
            - 時 (ji) = hour, 分 (fun/pun) = minute (e.g., 14時30分 = 14:30)
            - 毎週 (maishū) = every week, 毎日 (mainichi) = every day, 毎月 (maitsuki) = every month
            - @ or で indicates location

            Chinese (中文):
            - 明天 = tomorrow, 今天 = today, 下周 = next week
            - 星期一/周一 = Monday, 星期二/周二 = Tuesday, etc.
            - 上午 = AM, 下午 = PM
            - 点 = hour, 分 = minute (e.g., 14点30分 = 14:30)
            - 每天 = daily, 每周 = weekly, 每月 = monthly
            - 在 indicates location

            Korean (한국어):
            - 내일 = tomorrow, 오늘 = today, 다음 주 = next week
            - 월요일 = Monday, 화요일 = Tuesday, 수요일 = Wednesday, 목요일 = Thursday, 금요일 = Friday, 토요일 = Saturday, 일요일 = Sunday
            - 오전 = AM, 오후 = PM
            - 시 = hour, 분 = minute (e.g., 오후 2시 30분 = 14:30)
            - 매일 = daily, 매주 = weekly, 매월 = monthly
            - 에서 indicates location

            Spanish (Español):
            - mañana = tomorrow, hoy = today, la próxima semana = next week
            - lunes = Monday, martes = Tuesday, miércoles = Wednesday, jueves = Thursday, viernes = Friday, sábado = Saturday, domingo = Sunday
            - cada día = daily, cada semana = weekly, cada mes = monthly
            - en indicates location

            French (Français):
            - demain = tomorrow, aujourd'hui = today, la semaine prochaine = next week
            - lundi = Monday, mardi = Tuesday, mercredi = Wednesday, jeudi = Thursday, vendredi = Friday, samedi = Saturday, dimanche = Sunday
            - chaque jour = daily, chaque semaine = weekly, chaque mois = monthly
            - à indicates location

            German (Deutsch):
            - morgen = tomorrow, heute = today, nächste Woche = next week
            - Montag = Monday, Dienstag = Tuesday, Mittwoch = Wednesday, Donnerstag = Thursday, Freitag = Friday, Samstag = Saturday, Sonntag = Sunday
            - täglich = daily, wöchentlich = weekly, monatlich = monthly
            - in/bei indicates location

            Field extraction rules:
            - title: The main event name (concise, typically 2-5 words) IN THE SAME LANGUAGE AS INPUT
            - location: Physical or virtual location ONLY if explicitly mentioned (leave empty otherwise)
            - notes: All additional context, details, participants, or description provided by user

            Recurrence interpretation (all languages):
            - Look for patterns indicating repetition (every, 毎, 每, 매, cada, chaque, jede/r)
            - Map to recurrenceFrequency: "daily", "weekly", "monthly", or "yearly"
            - If interval specified (e.g., "every 2 weeks", "隔週"), set recurrenceInterval accordingly
            - If end date mentioned, set recurrenceEndDate
            - If no recurrence pattern found, leave all recurrence fields empty

            Distribute information appropriately: don't dump everything into title, and don't leave out details.
            Capture all user-provided information across the appropriate fields.

            Examples for each language:

            English:
            Input: "Lunch with Alex next Tue 1pm @Shibuya"
            Output: {"title": "Lunch with Alex", "start": "2025-12-09T13:00:00+09:00", "location": "Shibuya"}

            Input: "Team standup every Monday 9am until March"
            Output: {"title": "Team standup", "start": "2025-12-02T09:00:00+09:00", "recurrenceFrequency": "weekly", "recurrenceInterval": 1, "recurrenceEndDate": "2026-03-31T23:59:59+09:00"}

            Japanese (日本語):
            Input: "明日 14時 ランチ @渋谷"
            Output: {"title": "ランチ", "start": "2025-12-03T14:00:00+09:00", "location": "渋谷"}

            Input: "毎週月曜日 朝9時 チームミーティング"
            Output: {"title": "チームミーティング", "start": "2025-12-02T09:00:00+09:00", "recurrenceFrequency": "weekly", "recurrenceInterval": 1}

            Chinese (中文):
            Input: "明天下午2点 和小明吃饭 在星巴克"
            Output: {"title": "和小明吃饭", "start": "2025-12-03T14:00:00+08:00", "location": "星巴克"}

            Input: "每周五 下午3点 团队会议"
            Output: {"title": "团队会议", "start": "2025-12-06T15:00:00+08:00", "recurrenceFrequency": "weekly", "recurrenceInterval": 1}

            Korean (한국어):
            Input: "내일 오후 2시 점심 약속 강남에서"
            Output: {"title": "점심 약속", "start": "2025-12-03T14:00:00+09:00", "location": "강남"}

            Input: "매주 월요일 오전 10시 팀 미팅"
            Output: {"title": "팀 미팅", "start": "2025-12-02T10:00:00+09:00", "recurrenceFrequency": "weekly", "recurrenceInterval": 1}

            Spanish (Español):
            Input: "Almuerzo mañana a las 2pm en el centro"
            Output: {"title": "Almuerzo", "start": "2025-12-03T14:00:00-05:00", "location": "el centro"}

            French (Français):
            Input: "Réunion demain à 14h au bureau"
            Output: {"title": "Réunion", "start": "2025-12-03T14:00:00+01:00", "location": "bureau"}

            German (Deutsch):
            Input: "Meeting morgen um 14 Uhr im Büro"
            Output: {"title": "Meeting", "start": "2025-12-03T14:00:00+01:00", "location": "Büro"}
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

        // Generate structured output
        let response = try await session.respond(to: prompt, generating: ParsedEvent.self)
        let parsed = response.content

        // Validate and convert to CalendarEvent
        guard let start = DateUtil.parseISO8601(parsed.start, in: timezone) else {
            logger.error("parse: Failed to parse start date: \(parsed.start)")
            throw ParsingError.invalidDateFormat
        }

        let end = parsed.end.flatMap { DateUtil.parseISO8601($0, in: timezone) }

        // Parse recurrence if present
        var recurrence: RecurrenceRule? = nil
        if let freqString = parsed.recurrenceFrequency {
            if let frequency = RecurrenceRule.Frequency(rawValue: freqString.lowercased()) {
                let interval = parsed.recurrenceInterval ?? 1
                let endDate = parsed.recurrenceEndDate.flatMap { DateUtil.parseISO8601($0, in: timezone) }
                recurrence = RecurrenceRule(frequency: frequency, interval: interval, endDate: endDate)
                logger.info("parse: parsed recurrence rule: frequency=\(frequency.rawValue) interval=\(interval)")
            } else {
                logger.warning("parse: invalid recurrence frequency '\(freqString)', ignoring recurrence")
            }
        }

        let event = CalendarEvent(
            title: parsed.title,
            start: start,
            end: end,
            location: parsed.location,
            notes: parsed.notes,
            recurrence: recurrence,
            selectedCalendarId: nil
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
