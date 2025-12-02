//
//  SettingsView.swift
//  T2C
//
//  Minimal settings modal using native SwiftUI styling
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // Settings stored in UserDefaults via @AppStorage
    @AppStorage("defaultDuration") private var defaultDuration: Int = 60 // minutes
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Event Defaults
                Section {
                    Picker(String(localized: "settings.default_duration"), selection: $defaultDuration) {
                        Text(String(localized: "settings.duration.30min")).tag(30)
                        Text(String(localized: "settings.duration.1hour")).tag(60)
                        Text(String(localized: "settings.duration.2hours")).tag(120)
                    }
                } header: {
                    Text("settings.section.defaults", tableName: nil, bundle: .main, comment: "Defaults section")
                } footer: {
                    Text("settings.default_duration.footer", tableName: nil, bundle: .main, comment: "Duration footer")
                }

                // MARK: - Feedback
                Section {
                    Toggle(String(localized: "settings.haptic_feedback"), isOn: $hapticFeedback)
                } header: {
                    Text("settings.section.feedback", tableName: nil, bundle: .main, comment: "Feedback section")
                }

                // MARK: - About
                Section {
                    HStack {
                        Text(String(localized: "settings.version"))
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("settings.section.about", tableName: nil, bundle: .main, comment: "About section")
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
