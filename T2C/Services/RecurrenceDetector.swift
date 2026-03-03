//
//  RecurrenceDetector.swift
//  T2C
//
//  Regex-based smart recurring-pattern detection from natural language.
//  Acts as a deterministic pre-processor and fallback alongside the LLM parser.
//  Supports: English, Japanese (日本語), Chinese (中文), Korean (한국어),
//            Spanish (Español), French (Français), German (Deutsch)
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.t2c.app", category: "RecurrenceDetector")

// MARK: - RecurrenceDetector

/// Detects recurring event patterns from natural language using regex pattern matching.
/// Returns a `RecurrenceRule` when a recurring pattern is found, `nil` otherwise.
final class RecurrenceDetector {

    // MARK: - Public API

    /// Detect a `RecurrenceRule` from natural language text.
    /// - Parameter text: Natural language input (any supported language)
    /// - Returns: A `RecurrenceRule` if a recurring pattern is detected, `nil` otherwise
    func detect(in text: String) -> RecurrenceRule? {
        // 1. Day-of-week patterns imply weekly recurrence on specific days.
        //    Check these first since they're more specific than bare "weekly".
        if let (days, interval) = detectDayOfWeek(in: text) {
            let endCount = detectEndCount(in: text)
            let rule = RecurrenceRule(
                frequency: .weekly,
                interval: interval,
                endDate: nil,
                endCount: endCount,
                daysOfWeek: days
            )
            logger.info("detect: day-of-week → weekly/\(interval), days=\(days.map(\.rawValue))")
            return rule
        }

        // 2. General frequency patterns (daily / weekly / monthly / yearly)
        if let (frequency, interval) = detectFrequency(in: text) {
            let endCount = detectEndCount(in: text)
            let rule = RecurrenceRule(
                frequency: frequency,
                interval: interval,
                endDate: nil,
                endCount: endCount,
                daysOfWeek: nil
            )
            logger.info("detect: frequency pattern → \(frequency.rawValue)/\(interval)")
            return rule
        }

        return nil
    }

    // MARK: - Day-of-Week Detection

    private struct DayPattern {
        let pattern: String
        let days: [RecurrenceRule.DayOfWeek]
    }

    // swiftlint:disable line_length
    private let dayOfWeekPatterns: [DayPattern] = [
        // English – single days
        .init(pattern: #"(?i)\bevery(?:\s+other)?\s+monday\b"#,    days: [.monday]),
        .init(pattern: #"(?i)\bevery(?:\s+other)?\s+tuesday\b"#,   days: [.tuesday]),
        .init(pattern: #"(?i)\bevery(?:\s+other)?\s+wednesday\b"#, days: [.wednesday]),
        .init(pattern: #"(?i)\bevery(?:\s+other)?\s+thursday\b"#,  days: [.thursday]),
        .init(pattern: #"(?i)\bevery(?:\s+other)?\s+friday\b"#,    days: [.friday]),
        .init(pattern: #"(?i)\bevery(?:\s+other)?\s+saturday\b"#,  days: [.saturday]),
        .init(pattern: #"(?i)\bevery(?:\s+other)?\s+sunday\b"#,    days: [.sunday]),
        // English – groups
        .init(pattern: #"(?i)\bevery\s+weekday\b"#,   days: [.monday, .tuesday, .wednesday, .thursday, .friday]),
        .init(pattern: #"(?i)\bevery\s+weekend\b"#,   days: [.saturday, .sunday]),

        // Japanese
        .init(pattern: #"毎(週)?月曜"#, days: [.monday]),
        .init(pattern: #"毎(週)?火曜"#, days: [.tuesday]),
        .init(pattern: #"毎(週)?水曜"#, days: [.wednesday]),
        .init(pattern: #"毎(週)?木曜"#, days: [.thursday]),
        .init(pattern: #"毎(週)?金曜"#, days: [.friday]),
        .init(pattern: #"毎(週)?土曜"#, days: [.saturday]),
        .init(pattern: #"毎(週)?日曜"#, days: [.sunday]),
        .init(pattern: #"毎週末"#,      days: [.saturday, .sunday]),
        .init(pattern: #"毎平日"#,      days: [.monday, .tuesday, .wednesday, .thursday, .friday]),

        // Chinese
        .init(pattern: #"每[周週]一"#,        days: [.monday]),
        .init(pattern: #"每[周週]二"#,        days: [.tuesday]),
        .init(pattern: #"每[周週]三"#,        days: [.wednesday]),
        .init(pattern: #"每[周週]四"#,        days: [.thursday]),
        .init(pattern: #"每[周週]五"#,        days: [.friday]),
        .init(pattern: #"每[周週]六"#,        days: [.saturday]),
        .init(pattern: #"每[周週][日天]"#,    days: [.sunday]),
        .init(pattern: #"每个?工作日|每個?工作日"#, days: [.monday, .tuesday, .wednesday, .thursday, .friday]),
        .init(pattern: #"每个?[周週]末|每個?[周週]末"#, days: [.saturday, .sunday]),

        // Korean
        .init(pattern: #"매\s*월요일"#, days: [.monday]),
        .init(pattern: #"매\s*화요일"#, days: [.tuesday]),
        .init(pattern: #"매\s*수요일"#, days: [.wednesday]),
        .init(pattern: #"매\s*목요일"#, days: [.thursday]),
        .init(pattern: #"매\s*금요일"#, days: [.friday]),
        .init(pattern: #"매\s*토요일"#, days: [.saturday]),
        .init(pattern: #"매\s*일요일"#, days: [.sunday]),
        .init(pattern: #"매\s*평일"#,   days: [.monday, .tuesday, .wednesday, .thursday, .friday]),
        .init(pattern: #"매\s*주말"#,   days: [.saturday, .sunday]),

        // Spanish
        .init(pattern: #"(?i)\bcada\s+lunes\b"#,     days: [.monday]),
        .init(pattern: #"(?i)\bcada\s+martes\b"#,    days: [.tuesday]),
        .init(pattern: #"(?i)\bcada\s+miércoles\b"#, days: [.wednesday]),
        .init(pattern: #"(?i)\bcada\s+jueves\b"#,    days: [.thursday]),
        .init(pattern: #"(?i)\bcada\s+viernes\b"#,   days: [.friday]),
        .init(pattern: #"(?i)\bcada\s+sábado\b"#,    days: [.saturday]),
        .init(pattern: #"(?i)\bcada\s+domingo\b"#,   days: [.sunday]),
        .init(pattern: #"(?i)\bcada\s+día\s+laborable\b"#, days: [.monday, .tuesday, .wednesday, .thursday, .friday]),

        // French
        .init(pattern: #"(?i)\bchaque\s+lundi\b"#,    days: [.monday]),
        .init(pattern: #"(?i)\bchaque\s+mardi\b"#,    days: [.tuesday]),
        .init(pattern: #"(?i)\bchaque\s+mercredi\b"#, days: [.wednesday]),
        .init(pattern: #"(?i)\bchaque\s+jeudi\b"#,    days: [.thursday]),
        .init(pattern: #"(?i)\bchaque\s+vendredi\b"#, days: [.friday]),
        .init(pattern: #"(?i)\bchaque\s+samedi\b"#,   days: [.saturday]),
        .init(pattern: #"(?i)\bchaque\s+dimanche\b"#, days: [.sunday]),
        .init(pattern: #"(?i)\bchaque\s+jour\s+ouvré\b"#, days: [.monday, .tuesday, .wednesday, .thursday, .friday]),

        // German
        .init(pattern: #"(?i)\bjeden\s+Montag\b"#,     days: [.monday]),
        .init(pattern: #"(?i)\bjeden\s+Dienstag\b"#,   days: [.tuesday]),
        .init(pattern: #"(?i)\bjeden\s+Mittwoch\b"#,   days: [.wednesday]),
        .init(pattern: #"(?i)\bjeden\s+Donnerstag\b"#, days: [.thursday]),
        .init(pattern: #"(?i)\bjeden\s+Freitag\b"#,    days: [.friday]),
        .init(pattern: #"(?i)\bjeden\s+Samstag\b"#,    days: [.saturday]),
        .init(pattern: #"(?i)\bjeden\s+Sonntag\b"#,    days: [.sunday]),
        .init(pattern: #"(?i)\bjeden\s+Werktag\b"#,    days: [.monday, .tuesday, .wednesday, .thursday, .friday]),
    ]
    // swiftlint:enable line_length

    private func detectDayOfWeek(in text: String) -> ([RecurrenceRule.DayOfWeek], Int)? {
        for p in dayOfWeekPatterns {
            guard text.range(of: p.pattern, options: .regularExpression) != nil else { continue }
            // Check for "every other" variants → interval 2
            let everyOtherMarkers = ["every other", "隔週", "隔周", "격주"]
            let interval = everyOtherMarkers.contains(where: { text.lowercased().contains($0) }) ? 2 : 1
            return (p.days, interval)
        }
        return nil
    }

    // MARK: - Frequency Detection

    private struct FrequencyPattern {
        let pattern: String
        let frequency: RecurrenceRule.Frequency
        /// interval==0 means: extract the number from the first capture group
        let interval: Int
    }

    // swiftlint:disable line_length
    private let frequencyPatterns: [FrequencyPattern] = [
        // ── DAILY ──────────────────────────────────────────────────────────────
        .init(pattern: #"(?i)\bevery\s+day\b"#,               frequency: .daily, interval: 1),
        .init(pattern: #"(?i)\bdaily\b"#,                     frequency: .daily, interval: 1),
        .init(pattern: #"(?i)\bevery\s+other\s+day\b"#,       frequency: .daily, interval: 2),
        .init(pattern: #"(?i)\bevery\s+(\d+)\s+days?\b"#,     frequency: .daily, interval: 0),
        // Japanese
        .init(pattern: #"毎日"#,               frequency: .daily, interval: 1),
        .init(pattern: #"毎\s*(\d+)\s*日"#,   frequency: .daily, interval: 0),
        // Chinese (avoid matching 日期 = "date")
        .init(pattern: #"每[天日](?!期)"#,       frequency: .daily, interval: 1),
        .init(pattern: #"每\s*(\d+)\s*[天日]"#, frequency: .daily, interval: 0),
        // Korean
        .init(pattern: #"매일"#,             frequency: .daily, interval: 1),
        .init(pattern: #"매\s*(\d+)\s*일"#, frequency: .daily, interval: 0),
        // Spanish
        .init(pattern: #"(?i)\bcada\s+día\b"#,               frequency: .daily, interval: 1),
        .init(pattern: #"(?i)\bdiariamente\b"#,              frequency: .daily, interval: 1),
        .init(pattern: #"(?i)\bcada\s+(\d+)\s+días?\b"#,     frequency: .daily, interval: 0),
        // French
        .init(pattern: #"(?i)\bchaque\s+jour\b"#,            frequency: .daily, interval: 1),
        .init(pattern: #"(?i)\bquotidiennement\b"#,          frequency: .daily, interval: 1),
        .init(pattern: #"(?i)\btous\s+les\s+(\d+)\s+jours?\b"#, frequency: .daily, interval: 0),
        // German
        .init(pattern: #"(?i)\bjeden\s+Tag\b"#,              frequency: .daily, interval: 1),
        .init(pattern: #"(?i)\btäglich\b"#,                  frequency: .daily, interval: 1),
        .init(pattern: #"(?i)\balle\s+(\d+)\s+Tage?\b"#,    frequency: .daily, interval: 0),

        // ── WEEKLY ─────────────────────────────────────────────────────────────
        .init(pattern: #"(?i)\bevery\s+week\b"#,              frequency: .weekly, interval: 1),
        .init(pattern: #"(?i)\bweekly\b"#,                   frequency: .weekly, interval: 1),
        .init(pattern: #"(?i)\bevery\s+other\s+week\b"#,     frequency: .weekly, interval: 2),
        .init(pattern: #"(?i)\bbiweekly\b"#,                 frequency: .weekly, interval: 2),
        .init(pattern: #"(?i)\bevery\s+(\d+)\s+weeks?\b"#,   frequency: .weekly, interval: 0),
        // Japanese
        .init(pattern: #"毎週"#,            frequency: .weekly, interval: 1),
        .init(pattern: #"隔週"#,            frequency: .weekly, interval: 2),
        .init(pattern: #"毎\s*(\d+)\s*週"#, frequency: .weekly, interval: 0),
        // Chinese (avoid matching 周一…周日 which are day names)
        .init(pattern: #"每[周週](?![一二三四五六日天末])"#, frequency: .weekly, interval: 1),
        .init(pattern: #"隔[周週]"#,         frequency: .weekly, interval: 2),
        .init(pattern: #"每\s*(\d+)\s*[周週]"#, frequency: .weekly, interval: 0),
        // Korean
        .init(pattern: #"매주"#,            frequency: .weekly, interval: 1),
        .init(pattern: #"격주"#,            frequency: .weekly, interval: 2),
        .init(pattern: #"매\s*(\d+)\s*주"#, frequency: .weekly, interval: 0),
        // Spanish
        .init(pattern: #"(?i)\bcada\s+semana\b"#,             frequency: .weekly, interval: 1),
        .init(pattern: #"(?i)\bsemanalmente\b"#,              frequency: .weekly, interval: 1),
        .init(pattern: #"(?i)\bcada\s+(\d+)\s+semanas?\b"#,  frequency: .weekly, interval: 0),
        // French
        .init(pattern: #"(?i)\bchaque\s+semaine\b"#,          frequency: .weekly, interval: 1),
        .init(pattern: #"(?i)\bhebdomadairement\b"#,          frequency: .weekly, interval: 1),
        .init(pattern: #"(?i)\btoutes\s+les\s+(\d+)\s+semaines?\b"#, frequency: .weekly, interval: 0),
        // German
        .init(pattern: #"(?i)\bjede\s+Woche\b"#,              frequency: .weekly, interval: 1),
        .init(pattern: #"(?i)\bwöchentlich\b"#,               frequency: .weekly, interval: 1),
        .init(pattern: #"(?i)\balle\s+(\d+)\s+Wochen?\b"#,   frequency: .weekly, interval: 0),

        // ── MONTHLY ────────────────────────────────────────────────────────────
        .init(pattern: #"(?i)\bevery\s+month\b"#,             frequency: .monthly, interval: 1),
        .init(pattern: #"(?i)\bmonthly\b"#,                  frequency: .monthly, interval: 1),
        .init(pattern: #"(?i)\bevery\s+other\s+month\b"#,    frequency: .monthly, interval: 2),
        .init(pattern: #"(?i)\bevery\s+(\d+)\s+months?\b"#,  frequency: .monthly, interval: 0),
        // Japanese
        .init(pattern: #"毎月"#,             frequency: .monthly, interval: 1),
        .init(pattern: #"毎\s*(\d+)\s*ヶ?月"#, frequency: .monthly, interval: 0),
        // Chinese
        .init(pattern: #"每月"#,             frequency: .monthly, interval: 1),
        .init(pattern: #"每\s*(\d+)\s*月"#,  frequency: .monthly, interval: 0),
        // Korean
        .init(pattern: #"매[월달]"#,          frequency: .monthly, interval: 1),
        .init(pattern: #"매\s*(\d+)\s*월"#,  frequency: .monthly, interval: 0),
        // Spanish
        .init(pattern: #"(?i)\bcada\s+mes\b"#,                frequency: .monthly, interval: 1),
        .init(pattern: #"(?i)\bmensualmente\b"#,              frequency: .monthly, interval: 1),
        .init(pattern: #"(?i)\bcada\s+(\d+)\s+meses?\b"#,    frequency: .monthly, interval: 0),
        // French
        .init(pattern: #"(?i)\bchaque\s+mois\b"#,             frequency: .monthly, interval: 1),
        .init(pattern: #"(?i)\bmensuel(?:lement)?\b"#,        frequency: .monthly, interval: 1),
        .init(pattern: #"(?i)\btous\s+les\s+(\d+)\s+mois\b"#, frequency: .monthly, interval: 0),
        // German
        .init(pattern: #"(?i)\bjeden\s+Monat\b"#,             frequency: .monthly, interval: 1),
        .init(pattern: #"(?i)\bmonatlich\b"#,                 frequency: .monthly, interval: 1),
        .init(pattern: #"(?i)\balle\s+(\d+)\s+Monate?\b"#,   frequency: .monthly, interval: 0),

        // ── YEARLY ─────────────────────────────────────────────────────────────
        .init(pattern: #"(?i)\bevery\s+year\b"#,              frequency: .yearly, interval: 1),
        .init(pattern: #"(?i)\byearly\b"#,                   frequency: .yearly, interval: 1),
        .init(pattern: #"(?i)\bannually\b"#,                  frequency: .yearly, interval: 1),
        .init(pattern: #"(?i)\bevery\s+(\d+)\s+years?\b"#,   frequency: .yearly, interval: 0),
        // Japanese
        .init(pattern: #"毎年"#,             frequency: .yearly, interval: 1),
        .init(pattern: #"毎\s*(\d+)\s*年"#,  frequency: .yearly, interval: 0),
        // Chinese
        .init(pattern: #"每年"#,             frequency: .yearly, interval: 1),
        .init(pattern: #"每\s*(\d+)\s*年"#,  frequency: .yearly, interval: 0),
        // Korean
        .init(pattern: #"매년"#,             frequency: .yearly, interval: 1),
        .init(pattern: #"매\s*(\d+)\s*년"#,  frequency: .yearly, interval: 0),
        // Spanish
        .init(pattern: #"(?i)\bcada\s+año\b"#,                frequency: .yearly, interval: 1),
        .init(pattern: #"(?i)\banualmente\b"#,                frequency: .yearly, interval: 1),
        .init(pattern: #"(?i)\bcada\s+(\d+)\s+años?\b"#,     frequency: .yearly, interval: 0),
        // French
        .init(pattern: #"(?i)\bchaque\s+an(?:née)?\b"#,       frequency: .yearly, interval: 1),
        .init(pattern: #"(?i)\bannuellement\b"#,              frequency: .yearly, interval: 1),
        .init(pattern: #"(?i)\btous\s+les\s+(\d+)\s+ans?\b"#, frequency: .yearly, interval: 0),
        // German
        .init(pattern: #"(?i)\bjedes\s+Jahr\b"#,              frequency: .yearly, interval: 1),
        .init(pattern: #"(?i)\bjährlich\b"#,                  frequency: .yearly, interval: 1),
        .init(pattern: #"(?i)\balle\s+(\d+)\s+Jahre?\b"#,    frequency: .yearly, interval: 0),
    ]
    // swiftlint:enable line_length

    private func detectFrequency(in text: String) -> (RecurrenceRule.Frequency, Int)? {
        for p in frequencyPatterns {
            if p.interval == 0 {
                if let n = extractNumber(from: text, pattern: p.pattern) {
                    return (p.frequency, n)
                }
            } else if text.range(of: p.pattern, options: .regularExpression) != nil {
                return (p.frequency, p.interval)
            }
        }
        return nil
    }

    // MARK: - End-Count Detection

    /// Patterns that describe how many times an event should repeat.
    private let endCountPatterns: [String] = [
        #"(?i)\b(\d+)\s+times?\b"#,
        #"(?i)\bfor\s+(\d+)\s+occurrences?\b"#,
        #"(\d+)\s*回"#,   // Japanese/Chinese
        #"(\d+)\s*次"#,   // Chinese
        #"(\d+)\s*번"#,   // Korean
        #"(?i)\b(\d+)\s+veces?\b"#,          // Spanish
        #"(?i)\b(\d+)\s+fois?\b"#,           // French
        #"(?i)\b(\d+)\s*[Mm]al\b"#,          // German
    ]

    private func detectEndCount(in text: String) -> Int? {
        for pattern in endCountPatterns {
            if let n = extractNumber(from: text, pattern: pattern), n > 0 {
                return n
            }
        }
        return nil
    }

    // MARK: - Regex Helpers

    /// Extract the integer value of the **first capture group** in the first match.
    private func extractNumber(from text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1 else { return nil }
        let captureRange = match.range(at: 1)
        guard captureRange.location != NSNotFound,
              let swiftRange = Range(captureRange, in: text) else { return nil }
        return Int(text[swiftRange])
    }
}
