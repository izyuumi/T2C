//
//  TemplateService.swift
//  T2C
//
//  Input text templates for quick natural language event creation
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.t2c.app", category: "TemplateService")

/// Manages saved input text templates
final class TemplateService {

    static let shared = TemplateService()

    private let defaults = UserDefaults.standard
    private let templatesKey = "inputTemplates"
    private let hasLoadedDefaultsKey = "hasLoadedDefaultInputTemplates"

    struct InputTemplate: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        var text: String  // Natural language input text
        var createdAt: Date

        init(name: String, text: String) {
            self.id = UUID()
            self.name = name
            self.text = text
            self.createdAt = Date()
        }
    }

    private(set) var templates: [InputTemplate] = []

    private init() {
        loadTemplates()
        loadDefaultTemplatesIfNeeded()
    }

    // MARK: - CRUD Operations

    func addTemplate(_ template: InputTemplate) {
        templates.append(template)
        saveTemplates()
        logger.info("addTemplate: added '\(template.name)'")
    }

    func addTemplate(name: String, text: String) {
        let template = InputTemplate(name: name, text: text)
        addTemplate(template)
    }

    func updateTemplate(_ template: InputTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            saveTemplates()
            logger.info("updateTemplate: updated '\(template.name)'")
        }
    }

    func deleteTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
        saveTemplates()
        logger.info("deleteTemplate: removed template")
    }

    // MARK: - Persistence

    private func loadTemplates() {
        if let data = defaults.data(forKey: templatesKey),
           let decoded = try? JSONDecoder().decode([InputTemplate].self, from: data) {
            templates = decoded
            logger.debug("loadTemplates: loaded \(self.templates.count) templates")
        }
    }

    private func saveTemplates() {
        if let encoded = try? JSONEncoder().encode(templates) {
            defaults.set(encoded, forKey: templatesKey)
        }
    }

    // MARK: - Default Templates

    private func loadDefaultTemplatesIfNeeded() {
        // Only load defaults once on first launch
        guard !defaults.bool(forKey: hasLoadedDefaultsKey) else { return }

        // Don't overwrite if user already has templates
        guard templates.isEmpty else {
            defaults.set(true, forKey: hasLoadedDefaultsKey)
            return
        }

        logger.info("loadDefaultTemplatesIfNeeded: loading default templates for first launch")

        templates = Self.defaultTemplates
        saveTemplates()
        defaults.set(true, forKey: hasLoadedDefaultsKey)

        logger.info("loadDefaultTemplatesIfNeeded: loaded \(self.templates.count) default templates")
    }

    /// Default sample templates for first-time users
    static var defaultTemplates: [InputTemplate] {
        [
            // Work templates
            InputTemplate(
                name: "☕ Coffee Chat",
                text: "Coffee chat tomorrow 2pm"
            ),
            InputTemplate(
                name: "👥 Team Meeting",
                text: "Team meeting next Monday 10am @Conference Room"
            ),
            InputTemplate(
                name: "📞 Client Call",
                text: "Client call tomorrow 3pm"
            ),
            InputTemplate(
                name: "🔄 Weekly Standup",
                text: "Weekly standup every Monday 9am"
            ),
            InputTemplate(
                name: "💻 1:1 Meeting",
                text: "1:1 with [name] tomorrow 2pm"
            ),

            // Personal templates
            InputTemplate(
                name: "🍽️ Lunch",
                text: "Lunch tomorrow 12pm"
            ),
            InputTemplate(
                name: "🏋️ Gym",
                text: "Gym workout tomorrow 7am"
            ),
            InputTemplate(
                name: "🏥 Doctor",
                text: "Doctor appointment next [day] 10am"
            ),

            // Social templates
            InputTemplate(
                name: "🍻 Dinner",
                text: "Dinner with [name] this Saturday 7pm @[restaurant]"
            ),
            InputTemplate(
                name: "🎬 Movie",
                text: "Movie night this Friday 8pm"
            )
        ]
    }

    /// Reset to default templates (useful for testing or user request)
    func resetToDefaults() {
        templates = Self.defaultTemplates
        saveTemplates()
        logger.info("resetToDefaults: restored default templates")
    }
}
