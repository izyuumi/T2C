//
//  RecurrenceEditorView.swift
//  T2C
//
//  Recurrence rule editor sheet
//

import SwiftUI

struct RecurrenceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var recurrence: RecurrenceRule?
    let eventStart: Date

    @State private var frequency: RecurrenceRule.Frequency = .weekly
    @State private var interval: Int = 1
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "recurrence.editor.frequency"), selection: $frequency) {
                        Text(String(localized: "recurrence.daily")).tag(RecurrenceRule.Frequency.daily)
                        Text(String(localized: "recurrence.weekly")).tag(RecurrenceRule.Frequency.weekly)
                        Text(String(localized: "recurrence.monthly")).tag(RecurrenceRule.Frequency.monthly)
                        Text(String(localized: "recurrence.yearly")).tag(RecurrenceRule.Frequency.yearly)
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

                Section {
                    Toggle(String(localized: "recurrence.editor.has_end"), isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker(
                            String(localized: "recurrence.editor.end_date"),
                            selection: $endDate,
                            in: eventStart...,
                            displayedComponents: .date
                        )
                    }
                }

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
                    Button(String(localized: "recurrence.editor.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "recurrence.editor.done")) {
                        saveRecurrence()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadExisting()
            }
        }
    }

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
            hasEndDate = existing.endDate != nil
            endDate = existing.endDate ?? Calendar.current.date(byAdding: .month, value: 3, to: eventStart) ?? eventStart
        } else {
            // Default to 3 months from event start
            endDate = Calendar.current.date(byAdding: .month, value: 3, to: eventStart) ?? eventStart
        }
    }

    private func saveRecurrence() {
        recurrence = RecurrenceRule(
            frequency: frequency,
            interval: interval,
            endDate: hasEndDate ? endDate : nil
        )
    }
}

#Preview {
    RecurrenceEditorView(
        recurrence: .constant(RecurrenceRule(frequency: .weekly, interval: 1)),
        eventStart: Date()
    )
}
