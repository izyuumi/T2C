//
//  MainView.swift
//  T2C
//
//  Single-screen UI: input bar + dynamic result panel
//

import SwiftUI
import EventKit

struct MainView: View {

    @StateObject private var viewModel = MainViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Settings button (top-right)
            HStack {
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing)
                .padding(.top, 8)
            }

            // Dynamic result panel (top)
            resultPanel
                .frame(maxHeight: .infinity)
                .ignoresSafeArea(.keyboard, edges: .bottom)

            Divider()

            // Input bar (bottom)
            inputBar
                .padding()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Result Panel

    @ViewBuilder
    private var resultPanel: some View {
        VStack(spacing: 20) {
            switch viewModel.state {
            case .idle:
                idleView

            case .parsing:
                parsingView

            case .preview:
                previewView

            case .saving:
                savingView

            case .saved(let event):
                savedView(event: event)

            case .error(let parseError):
                errorView(parseError: parseError)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .animation(.easeInOut(duration: 0.3), value: viewModel.state)
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("app.title", tableName: nil, bundle: .main, comment: "App title")
                .font(.title2)
                .fontWeight(.semibold)

            Text("app.hint", tableName: nil, bundle: .main, comment: "App hint")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Quick input chips - localized
            HStack(spacing: 8) {
                quickChipButton(key: "chip.today_6pm")
                quickChipButton(key: "chip.tomorrow_9am")
                quickChipButton(key: "chip.next_monday_2pm")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    private func quickChipButton(key: String) -> some View {
        let localizedText = String(localized: String.LocalizationValue(key))
        return Button(action: {
            viewModel.text = localizedText
            isInputFocused = true
        }) {
            Text(localizedText)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(12)
        }
    }

    // MARK: - Parsing View

    private var parsingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("parsing.loading", tableName: nil, bundle: .main, comment: "Parsing loading")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    // MARK: - Preview View (Editable)

    private var previewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("preview.title", tableName: nil, bundle: .main, comment: "Preview title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    // Duration indicator if end time was inferred
                    if viewModel.editableEvent?.wasEndTimeInferred == true {
                        Text(defaultDurationText)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                    }
                }

                // Editable fields
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Label(String(localized: "preview.field.title"), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(String(localized: "preview.field.title.placeholder"), text: editableTitle)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Start Date & Time
                    VStack(alignment: .leading, spacing: 4) {
                        Label(String(localized: "preview.field.start"), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        DatePicker("", selection: editableStart, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)

                        // Past time warning
                        if let start = viewModel.editableEvent?.start, DateUtil.isPast(start) {
                            Label(String(localized: "preview.warning.past_time"), systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    // End Date & Time
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(String(localized: "preview.field.end"), systemImage: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            // Quick duration buttons
                            Spacer()
                            HStack(spacing: 8) {
                                ForEach(["30m", "1h", "2h"], id: \.self) { duration in
                                    Button(duration) {
                                        applyDuration(duration)
                                    }
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(6)
                                }
                            }
                        }

                        DatePicker("", selection: editableEnd, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    // Location (optional)
                    VStack(alignment: .leading, spacing: 4) {
                        Label(String(localized: "preview.field.location"), systemImage: "location")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(String(localized: "preview.field.location.placeholder"), text: editableLocation)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Notes (optional)
                    VStack(alignment: .leading, spacing: 4) {
                        Label(String(localized: "preview.field.notes"), systemImage: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(String(localized: "preview.field.notes.placeholder"), text: editableNotes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    // Recurrence (if present)
                    if let recurrence = viewModel.editableEvent?.recurrence {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(String(localized: "preview.field.repeats"), systemImage: "repeat")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Text(recurrenceDescription(recurrence))
                                    .font(.subheadline)

                                Spacer()

                                Button(action: { removeRecurrence() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                        }
                    }

                    // Calendar picker
                    if !viewModel.availableCalendars.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(String(localized: "preview.field.calendar"), systemImage: "tray.full")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker(String(localized: "preview.field.calendar"), selection: $viewModel.selectedCalendarId) {
                                ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                                    HStack {
                                        Circle()
                                            .fill(Color(cgColor: calendar.cgColor))
                                            .frame(width: 10, height: 10)
                                        Text(calendar.title)
                                    }
                                    .tag(calendar.calendarIdentifier as String?)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                }

                // Save button
                Button(action: {
                    Task {
                        await viewModel.save()
                        // Play haptic based on result
                        if case .saved = viewModel.state {
                            HapticUtil.playSuccess()
                        } else if case .error = viewModel.state {
                            HapticUtil.playError()
                        }
                    }
                }) {
                    Label(String(localized: "preview.button.add"), systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    // MARK: - Saving View

    private var savingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("saving.loading", tableName: nil, bundle: .main, comment: "Saving loading")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    // MARK: - Saved View

    private func savedView(event: CalendarEvent) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .scaleEffect(1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.state)

            VStack(spacing: 8) {
                Text("saved.title", tableName: nil, bundle: .main, comment: "Saved title")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(event.title)
                    .foregroundStyle(.secondary)

                if event.recurrence != nil {
                    Text("saved.recurring", tableName: nil, bundle: .main, comment: "Recurring event")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Button(action: {
                openCalendarApp()
            }) {
                Label(String(localized: "saved.button.open_calendar"), systemImage: "calendar")
            }
            .buttonStyle(.bordered)

            Button(String(localized: "saved.button.add_another")) {
                viewModel.reset()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Error View (with suggestions)

    private func errorView(parseError: MainViewModel.ParseError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)

            VStack(spacing: 12) {
                Text(parseError.message)
                    .font(.body)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)

                // Show what was understood (partial result)
                if let partial = parseError.partialResult {
                    VStack(alignment: .leading, spacing: 4) {
                        if let title = partial.title {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text("\(String(localized: "error.partial.title")) \(title)")
                                    .font(.caption)
                            }
                        }
                        HStack(spacing: 4) {
                            Image(systemName: partial.foundDate ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(partial.foundDate ? .green : .red)
                                .font(.caption)
                            Text("\(String(localized: "error.partial.date")) \(partial.foundDate ? String(localized: "error.partial.found") : String(localized: "error.partial.missing"))")
                                .font(.caption)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: partial.foundTime ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(partial.foundTime ? .green : .red)
                                .font(.caption)
                            Text("\(String(localized: "error.partial.time")) \(partial.foundTime ? String(localized: "error.partial.found") : String(localized: "error.partial.missing"))")
                                .font(.caption)
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }

                // Suggestions
                if !parseError.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("error.suggestions.header", tableName: nil, bundle: .main, comment: "Suggestions header")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(parseError.suggestions, id: \.self) { suggestion in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\u{2022}")
                                    .foregroundStyle(.secondary)
                                Text(suggestion)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }

            Button(String(localized: "error.button.retry")) {
                viewModel.state = .idle
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .transition(.opacity)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField(String(localized: "input.placeholder"), text: $viewModel.text, axis: .vertical)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .lineLimit(1...10)
                .textInputAutocapitalization(.sentences)
                .focused($isInputFocused)
                .background(Color(.systemBackground))
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )

            Button(action: {
                isInputFocused = false
                Task {
                    await viewModel.parse()
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(viewModel.text.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Editable Bindings

    private var editableTitle: Binding<String> {
        Binding(
            get: { viewModel.editableEvent?.title ?? "" },
            set: { viewModel.editableEvent?.title = $0 }
        )
    }

    private var editableStart: Binding<Date> {
        Binding(
            get: { viewModel.editableEvent?.start ?? Date() },
            set: { viewModel.editableEvent?.start = $0 }
        )
    }

    private var editableEnd: Binding<Date> {
        Binding(
            get: { viewModel.editableEvent?.end ?? Date() },
            set: {
                viewModel.editableEvent?.end = $0
                viewModel.editableEvent?.wasEndTimeInferred = false
            }
        )
    }

    private var editableLocation: Binding<String> {
        Binding(
            get: { viewModel.editableEvent?.location ?? "" },
            set: { viewModel.editableEvent?.location = $0.isEmpty ? nil : $0 }
        )
    }

    private var editableNotes: Binding<String> {
        Binding(
            get: { viewModel.editableEvent?.notes ?? "" },
            set: { viewModel.editableEvent?.notes = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: - Helpers

    private func openCalendarApp() {
        if let url = URL(string: "calshow://") {
            UIApplication.shared.open(url)
        }
    }

    private func applyDuration(_ duration: String) {
        guard let start = viewModel.editableEvent?.start else { return }

        let seconds: TimeInterval
        switch duration {
        case "30m": seconds = 1800
        case "1h": seconds = 3600
        case "2h": seconds = 7200
        default: return
        }

        viewModel.editableEvent?.end = start.addingTimeInterval(seconds)
        viewModel.editableEvent?.wasEndTimeInferred = false
    }

    private func recurrenceDescription(_ recurrence: RecurrenceRule) -> String {
        let every = String(localized: "recurrence.every")
        var desc = every

        if recurrence.interval > 1 {
            desc += " \(recurrence.interval)"
        }

        switch recurrence.frequency {
        case .daily:
            desc += " " + (recurrence.interval > 1 ? String(localized: "recurrence.days") : String(localized: "recurrence.day"))
        case .weekly:
            desc += " " + (recurrence.interval > 1 ? String(localized: "recurrence.weeks") : String(localized: "recurrence.week"))
        case .monthly:
            desc += " " + (recurrence.interval > 1 ? String(localized: "recurrence.months") : String(localized: "recurrence.month"))
        case .yearly:
            desc += " " + (recurrence.interval > 1 ? String(localized: "recurrence.years") : String(localized: "recurrence.year"))
        }

        if let endDate = recurrence.endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            desc += " \(String(localized: "recurrence.until")) \(formatter.string(from: endDate))"
        }

        return desc
    }

    private func removeRecurrence() {
        viewModel.editableEvent?.recurrence = nil
    }

    private var defaultDurationText: String {
        let minutes = UserDefaults.standard.integer(forKey: "defaultDuration")
        let duration = minutes > 0 ? minutes : 60
        switch duration {
        case 30:
            return String(localized: "settings.duration.30min") + " " + String(localized: "preview.duration_indicator")
        case 120:
            return String(localized: "settings.duration.2hours") + " " + String(localized: "preview.duration_indicator")
        default:
            return String(localized: "settings.duration.1hour") + " " + String(localized: "preview.duration_indicator")
        }
    }
}

#Preview {
    MainView()
}
