//
//  InputHistoryService.swift
//  T2C
//
//  Persists recently used text inputs for quick re-use.
//

import Foundation

struct InputHistoryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let text: String
    let date: Date

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.date = Date()
    }
}

final class InputHistoryService {
    static let shared = InputHistoryService()

    private let key = "inputHistory"
    private let maxEntries = 20

    private init() {}

    func entries() -> [InputHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([InputHistoryEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var list = entries()
        // Remove duplicate if same text already exists
        list.removeAll { $0.text.lowercased() == trimmed.lowercased() }
        list.insert(InputHistoryEntry(text: trimmed), at: 0)

        // Keep only recent entries
        if list.count > maxEntries {
            list = Array(list.prefix(maxEntries))
        }
        save(list)
    }

    func remove(_ entry: InputHistoryEntry) {
        var list = entries()
        list.removeAll { $0.id == entry.id }
        save(list)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func save(_ list: [InputHistoryEntry]) {
        if let encoded = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
