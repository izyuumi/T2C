//
//  RecurrenceEditorView.swift
//  T2C
//
//  Recurrence rule editor sheet – supports frequency, interval,
//  day-of-week selection (weekly), and date- or count-based end.
//

import SwiftUI

struct RecurrenceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var recurrence: RecurrenceRule?
    let eventStart: Date

    // MARK: - State

    @State private var frequency: RecurrenceRule.Frequency = .weekly
    @State private var interval: Int = 1
    @State private var selectedDays: Set<RecurrenceRule.DayOfWeek> = []

    enum EndType: String, CaseIterable {
        case never, onDate, afterCount
    }
    @State private var endType: EndType = .never
    @State private var endDate: Date = Date()
    @State private var endCount: Int = 10

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // ── Section 1: Frequency & Interval ─────────────────────────
                Section {
                    Picker(String(localized: "recurrence.editor.frequency"), selection: $frequency) {
                        Text(String(localized: "recurrence.daily")).tag(RecurrenceRule.Frequency.daily)
                        Text(String(localized: "recurrence.weekly")).tag(RecurrenceRule.Frequency.weekly)
                        Text(String(localized: "recurrence.monthly")).tag(RecurrenceRule.Frequency.monthly)
                        Text(String(localized: "recurrence.yearly")).tag(RecurrenceRule.Frequency.yearly)
                    }
                    .onChange(of: frequency) { _, _ in
                        // Clear day selection when switching away from weekly
                        if frequency != .weekly { selectedDays = [] }
                    }

                    Stepper(value: $interval, in: 1...30) {
                        HStack {
                            Text(String(localized: "recurrence.editor.every"))
                            Text("\(interval)")
                                .fontWeight(.semibold)
                            Text(intervalUnit)
                        }
                    }
                }

                // ── Section 2: Day of Week (weekly only) ─────────────────────
                if frequency == .weekly {
                    Section(header: Text(String(localized: "recurrence.editor.repeat_on"))) {
                        dayOfWeekGrid
                    }
                }

                // ── Section 3: End Repeat ────────────────────────────────────
                Section {
                    Picker(String(localized: "recurrence.editor.end_repeat"), selection: $endType) {
                        Text(String(localized: "recurrence.editor.end_never"))
                            .tag(EndType.never)
                        Text(String(localized: "recurrence.editor.end_on_date"))
                            .tag(EndType.onDate)
                        Text(String(localized: "recurrence.editor.end_after_count"))
                            .tag(EndType.afterCount)
                    }
                    .pickerStyle(.menu)

                    if endType == .onDate {
                        DatePicker(
                            String(localized: "recurrence.editor.end_date"),
                            selection: $endDate,
                            in: eventStart...,
                            displayedComponents: .date
                        )
                    }

                    if endType == .afterCount {
                        Stepper(value: $endCount, in: 1...999) {
                            HStack {
                                Text(String(localized: "recurrence.editor.end_after"))
                                Text("\(endCount)")
                                    .fontWeight(.semibold)
                                Text(String(localized: "recurrence.editor.occurrences"))
                            }
                        }
                    }
                }

                // ── Section 4: Remove ────────────────────────────────────────
                Section {
                    Button(role: .destructive, action: {
                        recurrence = nil
                        dismiss()
                    }) {
                        Text(String(localized: "recurrence.editor.remove"))
                    }
                }
            }
            .navigationTitle(String(localized: "recurrence.editor.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "recurrence.editor.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "recurrence.editor.done")) {
                        saveRecurrence()
                        dismiss()
                    }
                }
            }
            .onAppear { loadExisting() }
        }
    }

    // MARK: - Day-of-Week Grid

    private var dayOfWeekGrid: some View {
        let calendar = Calendar.current
        let shortNames = calendar.shortWeekdaySymbols  // ["Sun","Mon",…,"Sat"]
        // EKWeekday: sunday=1…saturday=7 → index = rawValue - 1
        let allDays = RecurrenceRule.DayOfWeek.allCases.sorted { $0.rawValue < $1.rawValue }

        return HStack(spacing: 6) {
            ForEach(allDays, id: \.rawValue) { day in
                let index = day.rawValue - 1
                let name = shortNames.indices.contains(index) ? shortNames[index] : "?"
                let isSelected = selectedDays.contains(day)

                Button(action: { toggleDay(day) }) {
                    Text(name)
                        .font(.caption)
                        .fontWeight(isSelected ? .bold : .regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .accessibilityLabel(name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private func toggleDay(_ day: RecurrenceRule.DayOfWeek) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }

    // MARK: - Helpers

    private var intervalUnit: String {
        switch frequency {
        case .daily:
            return interval == 1 ? String(localized: "recurrence.day") : String(localized: "recurrence.days")
        case .weekly:
            return interval == 1 ? String(localized: "recurrence.week") : String(localized: "recurrence.weeks")
        case .monthly:
            return interval == 1 ? String(localized: "recurrence.month") : String(localized: "recurrence.months")
        case .yearly:
            return interval == 1 ? String(localized: "recurrence.year") : String(localized: "recurrence.years")
        }
    }

    private func loadExisting() {
        if let existing = recurrence {
            frequency = existing.frequency
            interval = existing.interval

            if let days = existing.daysOfWeek, !days.isEmpty {
                selectedDays = Set(days)
            }

            if let count = existing.endCount, count > 0 {
                endType = .afterCount
                endCount = count
            } else if let date = existing.endDate {
                endType = .onDate
                endDate = date
            } else {
                endType = .never
            }

            // Default end date = 3 months from event start
            if endDate <= eventStart {
                endDate = Calendar.current.date(byAdding: .month, value: 3, to: eventStart) ?? eventStart
            }
        } else {
            endDate = Calendar.current.date(byAdding: .month, value: 3, to: eventStart) ?? eventStart
        }
    }

    private func saveRecurrence() {
        let resolvedEndDate = endType == .onDate ? endDate : nil
        let resolvedEndCount = endType == .afterCount ? endCount : nil
        let days = frequency == .weekly && !selectedDays.isEmpty
            ? Array(selectedDays).sorted { $0.rawValue < $1.rawValue }
            : nil

        recurrence = RecurrenceRule(
            frequency: frequency,
            interval: interval,
            endDate: resolvedEndDate,
            endCount: resolvedEndCount,
            daysOfWeek: days
        )
    }
}

#Preview {
    RecurrenceEditorView(
        recurrence: .constant(RecurrenceRule(frequency: .weekly, interval: 1, daysOfWeek: [.monday, .wednesday])),
        eventStart: Date()
    )
}
