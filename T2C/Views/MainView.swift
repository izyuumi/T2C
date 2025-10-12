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

    var body: some View {
        VStack(spacing: 0) {

            // Dynamic result panel (top)
            resultPanel
                .frame(maxHeight: .infinity)
                .ignoresSafeArea(.keyboard, edges: .bottom) // Prevent background from moving

            Divider()

            // Input bar (bottom)
            inputBar
                .padding()
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

            case .preview(let event):
                previewView(event: event)

            case .saving:
                savingView

            case .saved(let event):
                savedView(event: event)

            case .error(let message):
                errorView(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Text to Calendar")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Type something like:\n\"Lunch with Alex next Tue 1pm @Shibuya\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var parsingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Parsing...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func previewView(event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(event.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "calendar")
                }

                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.start, style: .date)
                        Text("\(event.start, style: .time) – \(event.end ?? event.start, style: .time)")
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "clock")
                }

                if let location = event.location {
                    Label {
                        Text(location)
                    } icon: {
                        Image(systemName: "location")
                    }
                }

                if let notes = event.notes {
                    Label {
                        Text(notes)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "note.text")
                    }
                }
            }

            Button(action: {
                Task {
                    await viewModel.save()
                }
            }) {
                Label("Add to Calendar", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var savingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Saving to Calendar...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func savedView(event: CalendarEvent) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Added to Calendar")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(event.title)
                    .foregroundStyle(.secondary)
            }

            Button(action: {
                openCalendarApp()
            }) {
                Label("Open Calendar", systemImage: "calendar")
            }
            .buttonStyle(.bordered)

            Button("Add Another") {
                viewModel.reset()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)

            Text(message)
                .font(.body)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)

            Button("Edit & Retry") {
                viewModel.state = .idle
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("e.g., Lunch with Alex next Tue 1pm", text: $viewModel.text, axis: .vertical)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .lineLimit(1...10)
                .textInputAutocapitalization(.sentences)
                .background(Color(.systemBackground))
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )

            Button(action: {
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

    // MARK: - Helpers

    private func openCalendarApp() {
        if let url = URL(string: "calshow://") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    MainView()
}
