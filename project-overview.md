Here’s a tight, build-ready overview for a minimal “Text → Calendar” iOS app with one input bar and a dynamic result screen.

Project Overview (Minimal)

Goal

Convert natural language like “Lunch with Alex next Tue 1pm @Shibuya” into a calendar event with the least UI and code possible.

Platform / Targets
• iOS (current Apple Intelligence cycle; Swift 5.9+)
• SwiftUI, FoundationModels (on-device LLM with tool calling), EventKit

App Flow (Single Screen) 1. Input bar (TextField) at bottom. 2. As the user types or taps “Parse”, the dynamic panel above updates:
• Parsing… (spinner)
• Parsed Preview (title, start–end, location, notes, “Add to Calendar” button)
• Validation hints (if fuzzy/ambiguous: show inline chips to resolve)
• Saved (brief confirmation; show “Open in Calendar”)

Minimal Feature Set
• Parse natural language into: {title, start, end?, location?, notes?}.
• Validate dates/time against TimeZone.current.
• Default duration = 60 min if end omitted.
• One-tap add via EventKit (write-only).
• Graceful errors and quick edits in-line.

Permissions (Info.plist)
• NSCalendarsWriteOnlyAccessUsageDescription: “Used to add events you confirm.”

Architecture (Keep It Tiny)

Layers (3):
• UI: MainView (SwiftUI)
• NLP: NLParser (FoundationModels tool-calling → strict JSON)
• Calendar: CalendarService (EventKit save/write-only)

State Machine (ViewModel)
• idle → parsing → preview(event) → saving → (saved | error(message))

Data Model

struct CalendarEvent: Codable, Equatable {
var title: String
var start: Date
var end: Date?
var location: String?
var notes: String?
}

File Layout (6 files total)

TextToCal/
App.swift
MainView.swift // Input bar + dynamic panel
MainViewModel.swift // State machine + intents
NLParser.swift // FoundationModels tool calling
CalendarService.swift // EventKit save
DateUtil.swift // ISO-8601 helpers + defaults

Core Interactions (pseudocode)

MainViewModel

@MainActor
final class MainViewModel: ObservableObject {
enum UIState { case idle, parsing, preview(CalendarEvent), saving, saved(CalendarEvent), error(String) }
@Published var text: String = ""
@Published var state: UIState = .idle

private let parser = NLParser()
private let cal = CalendarService()

func parse() async {
guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
state = .parsing
do {
var ev = try await parser.parse(text, tz: .current)
ev.end = ev.end ?? ev.start.addingTimeInterval(3600)
state = .preview(ev)
} catch { state = .error("Couldn’t understand that. Try adding a time or date.") }
}

func save() async {
guard case let .preview(ev) = state else { return }
state = .saving
do {
try await cal.requestWriteOnlyIfNeeded()
try cal.add(ev)
state = .saved(ev)
} catch { state = .error("Couldn’t save to Calendar.") }
}
}

NLParser (outline)
• Defines a parse_event tool schema (title, start/end as ISO-8601, location, notes).
• Prompts: “Return only a tool call to parse_event. Use ISO-8601 with timezone.”
• Parses tool call → CalendarEvent.

CalendarService (outline)
• requestWriteOnlyIfNeeded() using iOS 17+ EventKit API.
• add(\_ event: CalendarEvent) creates EKEvent and saves.

UI Details (one view)
• Top area: Card that switches content by UIState:
• parsing: ProgressView
• preview: title + start–end + location + “Add to Calendar”
• saved: “Added ✅” + button “Open Calendar”
• error: inline red text + “Edit & Retry”
• Bottom: TextField + Parse button (keyboard return also triggers parse).

Edge Cases & Handling
• No date found → suggest chips: “Today 6pm”, “Tomorrow 9am”, “Pick…”
• Past time → nudge: “That time has passed today — use tomorrow?”
• Time only → assume next occurrence of that time.
• Ambiguous names → leave in title; user can edit before save.

Testing (minimal)
• Unit tests for: text → parsed ISO-8601, default duration, timezone correctness.
• UI tests: parse, preview renders, save success path.

Telemetry / Logging (optional, off by default)
• Local debug logs for parse latency and save result.
• No network collection by default.

Roadmap (stretch, not in MVP)
• Voice input (Speech → text → same pipeline)
• Recurring events (“every Monday 9–10”)
• Calendar picker (choose which calendar)
• Attendees (Contacts permission)

⸻

Bottom line: One screen, three classes (ViewModel/NLParser/CalendarService), write-only calendar permission, strict tool-calling to JSON → preview → save. Keep everything ISO-8601 and timezone-aware for reliable parsing.
