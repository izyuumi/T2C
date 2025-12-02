//
//  AnalyticsService.swift
//  T2C
//
//  On-device analytics for tracking app usage patterns (no network, privacy-safe)
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.t2c.app", category: "Analytics")

/// On-device analytics tracking (all data stays local)
final class AnalyticsService {

    static let shared = AnalyticsService()

    private let defaults = UserDefaults.standard
    private let statsKey = "analyticsStats"

    // MARK: - Stats Model

    struct Stats: Codable {
        var totalParseAttempts: Int = 0
        var successfulParses: Int = 0
        var failedParses: Int = 0
        var timeoutErrors: Int = 0
        var totalEventsSaved: Int = 0
        var recurringEventsSaved: Int = 0
        var undoCount: Int = 0
        var languageUsage: [String: Int] = [:]  // detected input language
        var averageParseTimeMs: Double = 0
        var lastUsedDate: Date?

        var parseSuccessRate: Double {
            guard totalParseAttempts > 0 else { return 0 }
            return Double(successfulParses) / Double(totalParseAttempts) * 100
        }
    }

    private(set) var stats: Stats

    private init() {
        if let data = defaults.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(Stats.self, from: data) {
            stats = decoded
        } else {
            stats = Stats()
        }
    }

    // MARK: - Tracking Methods

    func trackParseAttempt() {
        stats.totalParseAttempts += 1
        stats.lastUsedDate = Date()
        save()
        logger.debug("trackParseAttempt: total=\(self.stats.totalParseAttempts)")
    }

    func trackParseSuccess(durationMs: Double, detectedLanguage: String? = nil) {
        stats.successfulParses += 1

        // Update rolling average
        let n = Double(stats.successfulParses)
        stats.averageParseTimeMs = ((n - 1) * stats.averageParseTimeMs + durationMs) / n

        if let lang = detectedLanguage {
            stats.languageUsage[lang, default: 0] += 1
        }

        save()
        logger.debug("trackParseSuccess: successRate=\(self.stats.parseSuccessRate)%")
    }

    func trackParseFailure(isTimeout: Bool) {
        stats.failedParses += 1
        if isTimeout {
            stats.timeoutErrors += 1
        }
        save()
        logger.debug("trackParseFailure: timeout=\(isTimeout)")
    }

    func trackEventSaved(isRecurring: Bool) {
        stats.totalEventsSaved += 1
        if isRecurring {
            stats.recurringEventsSaved += 1
        }
        save()
        logger.debug("trackEventSaved: total=\(self.stats.totalEventsSaved)")
    }

    func trackUndo() {
        stats.undoCount += 1
        save()
        logger.debug("trackUndo: count=\(self.stats.undoCount)")
    }

    // MARK: - Persistence

    private func save() {
        if let encoded = try? JSONEncoder().encode(stats) {
            defaults.set(encoded, forKey: statsKey)
        }
    }

    /// Reset all analytics (for privacy or testing)
    func resetStats() {
        stats = Stats()
        defaults.removeObject(forKey: statsKey)
        logger.info("resetStats: all analytics cleared")
    }

    /// Get a summary string for display
    func getSummary() -> String {
        """
        Parse attempts: \(stats.totalParseAttempts)
        Success rate: \(String(format: "%.1f", stats.parseSuccessRate))%
        Events saved: \(stats.totalEventsSaved)
        Recurring: \(stats.recurringEventsSaved)
        Avg parse time: \(String(format: "%.0f", stats.averageParseTimeMs))ms
        """
    }
}
