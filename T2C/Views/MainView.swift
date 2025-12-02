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
    @State private var showRecurrenceEditor = false
    @State private var showTemplates = false

    var body: some View {
        VStack(spacing: 0) {
            // Settings button (top-right)
            HStack {
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Settings")
                .accessibilityHint("Opens app settings")
                .padding(.trailing, 20)
                .padding(.top, 12)
            }

            // Dynamic result panel (top)
            resultPanel
                .frame(maxHeight: .infinity)
                .ignoresSafeArea(.keyboard, edges: .bottom)

            // Input bar (bottom)
            inputBar
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Result Panel

    @ViewBuilder
    private var resultPanel: some View {
        Group {
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
        .animation(.easeInOut(duration: 0.3), value: viewModel.state)
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 16) {
            Spacer()

            // Icon with background
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 6) {
                Text("app.title", tableName: nil, bundle: .main, comment: "App title")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("app.hint", tableName: nil, bundle: .main, comment: "App hint")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Quick input chips - localized
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    quickChipButton(key: "chip.today_6pm")
                    quickChipButton(key: "chip.tomorrow_9am")
                }
                quickChipButton(key: "chip.next_monday_2pm")
            }
            .padding(.top, 12)

            // Templates button
            Button {
                showTemplates = true
            } label: {
                Label(String(localized: "templates.button"), systemImage: "doc.on.doc")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .padding(.top, 8)
            .accessibilityLabel("Templates")
            .accessibilityHint("Opens saved event templates")

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .sheet(isPresented: $showTemplates) {
            TemplatesView { template in
                applyTemplate(template)
            }
        }
    }

    private func quickChipButton(key: String) -> some View {
        let localizedText = String(localized: String.LocalizationValue(key))
        return Button(action: {
            viewModel.text = localizedText
            isInputFocused = true
        }) {
            Text(localizedText)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
                )
        }
        .accessibilityLabel(localizedText)
        .accessibilityHint("Tap to use this example")
    }

    // MARK: - Parsing View

    private var parsingView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)

                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.blue)
            }

            Text("parsing.loading", tableName: nil, bundle: .main, comment: "Parsing loading")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    // MARK: - Preview View (Editable)

    private var previewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Title Section
                VStack(alignment: .leading, spacing: 8) {
                    TextField(String(localized: "preview.field.title.placeholder"), text: editableTitle)
                        .font(.system(size: 24, weight: .semibold))
                        .accessibilityLabel("Event title")

                    // Duration indicator if end time was inferred
                    if viewModel.editableEvent?.wasEndTimeInferred == true {
                        Text(defaultDurationText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.12))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                            .accessibilityLabel("Default duration applied")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                Divider()
                    .padding(.horizontal, 20)

                // Date & Time Section
                VStack(spacing: 0) {
                    // Start
                    previewRow(icon: "clock", iconColor: .blue) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "preview.field.start"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                dateChip(date: editableStart.wrappedValue, components: .date, binding: editableStart)
                                dateChip(date: editableStart.wrappedValue, components: .hourAndMinute, binding: editableStart)
                            }

                            // Past time warning
                            if let start = viewModel.editableEvent?.start, DateUtil.isPast(start) {
                                Label(String(localized: "preview.warning.past_time"), systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .padding(.top, 4)
                                    .accessibilityLabel("Warning: this time is in the past")
                            }
                        }
                    }

                    // End
                    previewRow(icon: "clock.badge.checkmark", iconColor: .green) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(String(localized: "preview.field.end"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                // Quick duration buttons
                                HStack(spacing: 6) {
                                    ForEach(["30m", "1h", "2h"], id: \.self) { duration in
                                        Button(duration) {
                                            applyDuration(duration)
                                        }
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                        .accessibilityLabel("Set duration to \(duration)")
                                        .accessibilityHint("Sets event length")
                                    }
                                }
                            }

                            HStack(spacing: 8) {
                                dateChip(date: editableEnd.wrappedValue, components: .date, binding: editableEnd)
                                dateChip(date: editableEnd.wrappedValue, components: .hourAndMinute, binding: editableEnd)
                            }
                        }
                    }
                }

                Divider()
                    .padding(.horizontal, 20)

                // Location & Notes Section
                VStack(spacing: 0) {
                    // Location
                    previewRow(icon: "mappin.and.ellipse", iconColor: .red) {
                        TextField(String(localized: "preview.field.location.placeholder"), text: editableLocation)
                            .font(.body)
                            .accessibilityLabel("Event location")
                    }

                    // Notes
                    previewRow(icon: "text.alignleft", iconColor: .purple) {
                        TextField(String(localized: "preview.field.notes.placeholder"), text: editableNotes, axis: .vertical)
                            .font(.body)
                            .lineLimit(2...4)
                            .accessibilityLabel("Event notes")
                    }
                }

                Divider()
                    .padding(.horizontal, 20)

                // Recurrence & Calendar Section
                VStack(spacing: 0) {
                    // Recurrence
                    previewRow(icon: "repeat", iconColor: .teal) {
                        if let recurrence = viewModel.editableEvent?.recurrence {
                            HStack {
                                Text(recurrenceDescription(recurrence))
                                    .font(.body)

                                Spacer()

                                Button(action: { showRecurrenceEditor = true }) {
                                    Image(systemName: "pencil")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                }
                                .accessibilityLabel(String(localized: "preview.recurrence.edit"))

                                Button(action: { removeRecurrence() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary.opacity(0.5))
                                }
                                .accessibilityLabel(String(localized: "preview.recurrence.remove"))
                            }
                        } else {
                            Button(action: { showRecurrenceEditor = true }) {
                                Text(String(localized: "preview.recurrence.add"))
                                    .font(.body)
                                    .foregroundStyle(.blue)
                            }
                            .accessibilityLabel(String(localized: "preview.recurrence.add"))
                            .accessibilityHint(String(localized: "preview.recurrence.add.hint"))
                        }
                    }
                    .sheet(isPresented: $showRecurrenceEditor) {
                        RecurrenceEditorView(
                            recurrence: Binding(
                                get: { viewModel.editableEvent?.recurrence },
                                set: { viewModel.editableEvent?.recurrence = $0 }
                            ),
                            eventStart: viewModel.editableEvent?.start ?? Date()
                        )
                    }

                    // Calendar picker
                    if !viewModel.availableCalendars.isEmpty {
                        previewRow(icon: "calendar", iconColor: Color(cgColor: selectedCalendarColor)) {
                            Picker(String(localized: "preview.field.calendar"), selection: $viewModel.selectedCalendarId) {
                                ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(cgColor: calendar.cgColor))
                                            .frame(width: 8, height: 8)
                                        Text(calendar.title)
                                    }
                                    .tag(calendar.calendarIdentifier as String?)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .accessibilityLabel("Select calendar")
                        }
                    }
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.reset()
                    }) {
                        Text(String(localized: "preview.button.cancel"))
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityLabel(String(localized: "preview.button.cancel"))
                    .accessibilityHint("Cancels and returns to input")

                    Button(action: {
                        Task {
                            await viewModel.save()
                            if case .saved = viewModel.state {
                                HapticUtil.playSuccess()
                            } else if case .error = viewModel.state {
                                HapticUtil.playError()
                            }
                        }
                    }) {
                        Label(String(localized: "preview.button.add"), systemImage: "plus")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityLabel("Add to Calendar")
                    .accessibilityHint("Saves the event to your calendar")
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }

    // MARK: - Preview Row Component

    private func previewRow<Content: View>(
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Date Chip Component

    private func dateChip(date: Date, components: DatePickerComponents, binding: Binding<Date>) -> some View {
        DatePicker("", selection: binding, displayedComponents: components)
            .labelsHidden()
            .datePickerStyle(.compact)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Selected Calendar Color

    private var selectedCalendarColor: CGColor {
        if let calendarId = viewModel.selectedCalendarId,
           let calendar = viewModel.availableCalendars.first(where: { $0.calendarIdentifier == calendarId }) {
            return calendar.cgColor
        }
        return UIColor.systemBlue.cgColor
    }

    // MARK: - Saving View

    private var savingView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)

                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.green)
            }

            Text("saving.loading", tableName: nil, bundle: .main, comment: "Saving loading")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    // MARK: - Saved View

    private func savedView(event: CalendarEvent) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Success icon with animated ring
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)

                Circle()
                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 3)
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.green)
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.state)

            VStack(spacing: 8) {
                Text("saved.title", tableName: nil, bundle: .main, comment: "Saved title")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(event.title)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if event.recurrence != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.caption)
                        Text("saved.recurring", tableName: nil, bundle: .main, comment: "Recurring event")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            VStack(spacing: 12) {
                Button(action: {
                    openCalendarApp()
                }) {
                    Label(String(localized: "saved.button.open_calendar"), systemImage: "calendar")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .accessibilityLabel("Open Calendar app")
                .accessibilityHint("Opens the Calendar app to view your event")

                Button(String(localized: "saved.button.add_another")) {
                    viewModel.reset()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Add another event")
                .accessibilityHint("Clears form to add a new event")
            }
            .padding(.top, 8)

            // Undo button (appears when undo is available)
            if viewModel.canUndo {
                Button(role: .destructive) {
                    Task {
                        await viewModel.undoLastSave()
                    }
                } label: {
                    Label(String(localized: "saved.button.undo"), systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .transition(.opacity.combined(with: .scale))
                .accessibilityLabel("Undo last save")
                .accessibilityHint("Removes the last saved event from your calendar")
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Error View (with suggestions)

    private func errorView(parseError: MainViewModel.ParseError) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                // Error icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.red)
                }

                VStack(spacing: 16) {
                    Text(parseError.message)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Show what was understood (partial result)
                    if let partial = parseError.partialResult {
                        VStack(alignment: .leading, spacing: 8) {
                            if let title = partial.title {
                                partialResultRow(
                                    icon: "checkmark.circle.fill",
                                    iconColor: .green,
                                    text: "\(String(localized: "error.partial.title")) \(title)"
                                )
                            }
                            partialResultRow(
                                icon: partial.foundDate ? "checkmark.circle.fill" : "xmark.circle.fill",
                                iconColor: partial.foundDate ? .green : .red,
                                text: "\(String(localized: "error.partial.date")) \(partial.foundDate ? String(localized: "error.partial.found") : String(localized: "error.partial.missing"))"
                            )
                            partialResultRow(
                                icon: partial.foundTime ? "checkmark.circle.fill" : "xmark.circle.fill",
                                iconColor: partial.foundTime ? .green : .red,
                                text: "\(String(localized: "error.partial.time")) \(partial.foundTime ? String(localized: "error.partial.found") : String(localized: "error.partial.missing"))"
                            )
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 24)
                    }

                    // Suggestions
                    if !parseError.suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("error.suggestions.header", tableName: nil, bundle: .main, comment: "Suggestions header")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)

                            ForEach(parseError.suggestions, id: \.self) { suggestion in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 24)
                    }
                }

                Button(action: {
                    viewModel.state = .idle
                }) {
                    Text(String(localized: "error.button.retry"))
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .accessibilityLabel("Edit and retry")
                .accessibilityHint("Go back to edit your text")

                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    private func partialResultRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.subheadline)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(String(localized: "input.placeholder"), text: $viewModel.text, axis: .vertical)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .lineLimit(1...10)
                .textInputAutocapitalization(.sentences)
                .focused($isInputFocused)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button(action: {
                isInputFocused = false
                Task {
                    await viewModel.parse()
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        viewModel.text.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color(.tertiaryLabel)
                            : Color.blue
                    )
            }
            .disabled(viewModel.text.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Parse event")
            .accessibilityHint("Parses your text into a calendar event")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
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

    private func applyTemplate(_ template: TemplateService.InputTemplate) {
        // Set the template text in the input field for user to edit
        viewModel.text = template.text
        isInputFocused = true
    }
}

#Preview {
    MainView()
}
