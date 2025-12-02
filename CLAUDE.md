# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

T2C is a minimal iOS app that converts natural language text (e.g., "Lunch with Alex next Tue 1pm @Shibuya") into calendar events. The app uses on-device LLM via FoundationModels guided generation and write-only EventKit access.

**Platform**: iOS (requires iOS 17+ for write-only calendar access), Swift 5.9+, SwiftUI

**Key Technologies**:

- **FoundationModels**: On-device LLM with guided generation using `@Generable` macro and `LanguageModelSession`
- **EventKit**: Write-only calendar access (with calendar selection support)
- **SwiftUI**: Single-screen UI with state-driven display and animations

## Build & Run Commands

ONLY the user will run and build the app.

## Architecture

### Three-Layer Design

1. **UI Layer**: `MainView` (SwiftUI) - single screen with input bar and dynamic result panel
2. **Business Logic**: `MainViewModel` - state machine orchestration
3. **Services**: `NLParser` (FoundationModels), `CalendarService` (EventKit)

### State Machine (MainViewModel)

The app follows a strict state machine pattern in `MainViewModel.swift`:

```
idle → parsing → preview(CalendarEvent) → saving → (saved | error)
                     ↓
                  error(ParseError)
```

**States**:

- `idle`: Initial state, waiting for input
- `parsing`: NLParser is processing text via FoundationModels
- `preview(CalendarEvent)`: Shows editable parsed event, user can modify and confirm
- `saving`: Writing to calendar via EventKit
- `saved(CalendarEvent)`: Success confirmation with haptic feedback
- `error(ParseError)`: Structured error with suggestions for recovery

### Key Design Patterns

**Guided Generation with FoundationModels**:

- `NLParser.swift` uses `@Generable` macro on `ParsedEvent` struct to define the output schema
- `@Guide` attributes provide field-level descriptions to the model
- `LanguageModelSession` maintains system prompt and handles structured output
- All dates are ISO-8601 with timezone (e.g., `2025-10-12T14:00:00+09:00`)
- Supports recurring event patterns (daily, weekly, monthly, yearly)

**Editable Preview**:

- Parsed events are stored in `editableEvent` for in-place editing
- Users can modify title, start/end times, location, notes before saving
- Quick duration buttons (30m, 1h, 2h) for easy end time adjustment
- Duration indicator badge shows when default 1-hour duration was applied

**Calendar Selection**:

- `CalendarService.getCalendars()` fetches all available calendars
- Users can select target calendar in preview state
- Falls back to default calendar if none selected

**Recurring Events**:

- `RecurrenceRule` struct with frequency (daily/weekly/monthly/yearly), interval, and optional end date
- Parser detects patterns like "every Monday", "daily at 9am", "every 2 weeks"
- Maps to `EKRecurrenceRule` when saving to EventKit

**Timezone-Aware Date Handling**:

- `DateUtil` handles all ISO-8601 parsing/formatting with timezone context
- Current timezone is always passed to parser for context
- Default 60-minute duration applied if end time is omitted (tracked via `wasEndTimeInferred`)

## File Structure

```
T2C/
├── App/
│   └── T2CApp.swift              # App entry point with haptic setup
├── Views/
│   └── MainView.swift            # Single-screen UI with editable preview
├── ViewModels/
│   └── MainViewModel.swift       # State machine + async intents + error handling
├── Services/
│   ├── NLParser.swift            # FoundationModels guided generation + recurrence parsing
│   └── CalendarService.swift     # EventKit access + RecurrenceRule + CalendarEvent model
└── Utilities/
    ├── DateUtil.swift            # ISO-8601 helpers, timezone handling
    └── HapticUtil.swift          # Haptic feedback (success/error) + simulator suppression
```

## Important Implementation Details

### FoundationModels Integration

- `ParsedEvent` struct defines the schema for model output via `@Generable` macro
- Fields: title, start, end, location, notes, recurrenceFrequency, recurrenceInterval, recurrenceEndDate
- System prompt in `NLParser.init()` guides the model on date interpretation, field distribution, and recurrence patterns
- Each request includes current date/time and timezone as context
- Model returns structured JSON matching `ParsedEvent` schema

### Date Parsing Rules (NLParser.swift)

- Time only → next occurrence from current time
- No end time → left empty (60-min default applied by ViewModel, marked as `wasEndTimeInferred`)
- Relative dates (tomorrow, next week) → interpreted from current date
- All dates must be ISO-8601 with timezone

### Recurrence Parsing Rules (NLParser.swift)

- "every Monday" → weekly recurrence, start date adjusted to next Monday
- "daily at 9am" → daily recurrence
- "every 2 weeks" → weekly with interval 2
- "until December" → recurrence end date set to end of month

### CalendarEvent Model (CalendarService.swift)

```swift
struct CalendarEvent: Codable, Equatable {
    var title: String
    var start: Date
    var end: Date?
    var location: String?
    var notes: String?
    var recurrence: RecurrenceRule?
    var selectedCalendarId: String?
    var wasEndTimeInferred: Bool = false
}

struct RecurrenceRule: Codable, Equatable {
    enum Frequency: String, Codable, CaseIterable {
        case daily, weekly, monthly, yearly
    }
    var frequency: Frequency
    var interval: Int = 1
    var endDate: Date?
}
```

### Calendar Permissions

- Required: `NSCalendarsWriteOnlyAccessUsageDescription` in Info.plist
- Write-only access is requested (privacy-preserving)
- Calendars are fetched for selection in preview state
- Permission flow handled in `CalendarService.requestWriteOnlyIfNeeded()`

### Error Handling

**Structured ParseError** (MainViewModel.swift):

```swift
struct ParseError: Equatable {
    let message: String
    let suggestions: [String]
    let partialResult: PartialParseResult?
}

struct PartialParseResult: Equatable {
    var title: String?
    var foundDate: Bool
    var foundTime: Bool
}
```

**Error types with contextual suggestions**:

- `TimeoutError` → "Try a simpler phrase", "Break into separate events"
- `ParsingError.invalidDateFormat` → "Add a specific date like 'tomorrow'", "Use format like '2pm'"
- `CalendarError.permissionDenied` → "Check calendar permissions in Settings"
- `CalendarError.saveFailed(Error)` → EventKit-specific error message

### Haptic Feedback (HapticUtil.swift)

- `playSuccess()`: Triggers success notification haptic on real devices
- `playError()`: Triggers error notification haptic on real devices
- Both are no-ops in simulator to avoid warnings
- Success haptic plays after successful save, error haptic on failure

### Logging

Uses `OSLog` with structured logging:

- Subsystem: `com.t2c.app`
- Categories: `MainViewModel`, `NLParser`, `CalendarService`, `HapticUtil`
- Info-level for state transitions, debug-level for intermediate steps
- Logs recurrence parsing details and calendar selection

## UI/UX Features

### Editable Preview

- All parsed fields are editable via text fields and date pickers
- Duration indicator badge (orange) shows when 1-hour default was applied
- Quick duration buttons: 30m, 1h, 2h
- Past time warning (orange) if start time is in the past
- Recurrence display with remove button
- Calendar picker dropdown with color indicators

### Error Recovery UI

- Shows partial parse results (what was understood: title, date, time)
- Bulleted suggestions list for how to fix the input
- "Edit & Retry" button returns to idle with text preserved

### Animations & Transitions

- State transitions animated with `easeInOut(duration: 0.3)`
- Preview slides in from right, out to left
- Success checkmark has spring animation
- Saved state uses scale + opacity transition

## Testing Strategy (Planned)

The project-overview.md specifies minimal testing:

- Unit tests: text → ISO-8601 parsing, default duration logic, timezone correctness, recurrence parsing
- UI tests: parse flow, preview editing, calendar selection, save success path

No tests currently exist; tests should be added in future iterations.

## Multi-Language Support

The app supports 7 languages for both UI and natural language parsing:

| Language | Code | UI Localized | NLP Parsing |
|----------|------|--------------|-------------|
| English | en | Yes | Yes |
| Japanese | ja | Yes | Yes |
| Chinese (Simplified) | zh-Hans | Yes | Yes |
| Korean | ko | Yes | Yes |
| Spanish | es | Yes | Yes |
| French | fr | Yes | Yes |
| German | de | Yes | Yes |

### Localization Files

Located in `T2C/Resources/{lang}.lproj/Localizable.strings`:

- All UI strings use `String(localized:)` or `Text("key", tableName:bundle:comment:)`
- Quick chips are localized (e.g., "Today 6pm" → "今日 18時" in Japanese)
- Error messages and suggestions are localized
- Recurrence descriptions are localized

### NLParser Multi-Language Support

The system prompt in `NLParser.swift` includes language-specific patterns:

**Japanese (日本語)**:
- Dates: 明日, 今日, 来週, 月曜日~日曜日
- Times: 午前/午後, 時/分 (e.g., 14時30分)
- Location: @ or で
- Recurrence: 毎日, 毎週, 毎月

**Chinese (中文)**:
- Dates: 明天, 今天, 下周, 星期一~星期日
- Times: 上午/下午, 点/分 (e.g., 14点30分)
- Location: 在
- Recurrence: 每天, 每周, 每月

**Korean (한국어)**:
- Dates: 내일, 오늘, 다음 주, 월요일~일요일
- Times: 오전/오후, 시/분 (e.g., 오후 2시 30분)
- Location: 에서
- Recurrence: 매일, 매주, 매월

**Spanish (Español)**:
- Dates: mañana, hoy, la próxima semana, lunes~domingo
- Times: Standard 12h/24h format
- Location: en
- Recurrence: cada día, cada semana, cada mes

**French (Français)**:
- Dates: demain, aujourd'hui, la semaine prochaine, lundi~dimanche
- Times: Standard 24h format
- Location: à
- Recurrence: chaque jour, chaque semaine, chaque mois

**German (Deutsch)**:
- Dates: morgen, heute, nächste Woche, Montag~Sonntag
- Times: Standard 24h format (e.g., 14 Uhr)
- Location: in/bei
- Recurrence: täglich, wöchentlich, monatlich

### Multi-Language Date Detection

`MainViewModel.containsDateKeywords()` detects date keywords in all supported languages for error recovery hints.

`MainViewModel.containsTimePattern()` detects time patterns including:
- English: 2pm, 14:00
- Japanese: 14時, 午後2時
- Chinese: 14点, 下午2点
- Korean: 14시, 오후 2시

## Edge Cases & UX Considerations

- No date found → suggest quick chips (Today 6pm, Tomorrow 9am) - localized per language
- Past time → orange warning in preview, user can adjust
- Ambiguous info → distributed across title/notes, user can edit before save
- End time inferred → orange badge indicator, quick duration buttons available
- Recurring events → displayed in preview, removable before save

## Development Notes

- Single-screen design: no navigation, all UI states handled via conditional rendering in MainView
- Haptics are disabled in simulator via compile-time `#if !targetEnvironment(simulator)`
- **CHHapticPattern Simulator Warnings**: The simulator logs repeated `CHHapticPattern.mm` errors about missing `hapticpatternlibrary.plist`. These are harmless iOS simulator limitations and don't affect app functionality.
- Default duration: 60 minutes (3600 seconds) in `DateUtil.defaultDuration`
- All async operations are marked with `@MainActor` for UI safety
- Calendar selection requires write-only access to have been granted first
