# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

T2C is a minimal iOS app that converts natural language text (e.g., "Lunch with Alex next Tue 1pm @Shibuya") into calendar events. The app uses on-device LLM via FoundationModels guided generation and write-only EventKit access.

**Platform**: iOS (requires iOS 17+ for write-only calendar access), Swift 5.9+, SwiftUI

**Key Technologies**:
- **FoundationModels**: On-device LLM with guided generation using `@Generable` macro and `LanguageModelSession`
- **EventKit**: Write-only calendar access (no read permissions)
- **SwiftUI**: Single-screen UI with state-driven display

## Build & Run Commands

```bash
# Build the project
xcodebuild -project T2C.xcodeproj -scheme T2C -configuration Debug build

# Clean build folder
xcodebuild -project T2C.xcodeproj -scheme T2C clean

# Build for testing (when tests are added)
xcodebuild -project T2C.xcodeproj -scheme T2C -configuration Debug build-for-testing

# Run tests (when tests exist)
xcodebuild -project T2C.xcodeproj -scheme T2C test
```

## Architecture

### Three-Layer Design
1. **UI Layer**: `MainView` (SwiftUI) - single screen with input bar and dynamic result panel
2. **Business Logic**: `MainViewModel` - state machine orchestration
3. **Services**: `NLParser` (FoundationModels), `CalendarService` (EventKit)

### State Machine (MainViewModel)
The app follows a strict state machine pattern in `MainViewModel.swift:20`:

```
idle → parsing → preview(CalendarEvent) → saving → (saved | error)
                     ↓
                  error
```

**States**:
- `idle`: Initial state, waiting for input
- `parsing`: NLParser is processing text via FoundationModels
- `preview(CalendarEvent)`: Shows parsed event, user can confirm
- `saving`: Writing to calendar via EventKit
- `saved(CalendarEvent)`: Success confirmation
- `error(String)`: Any failure state with message

### Key Design Patterns

**Guided Generation with FoundationModels**:
- `NLParser.swift` uses `@Generable` macro on `ParsedEvent` struct to define the output schema
- `@Guide` attributes provide field-level descriptions to the model
- `LanguageModelSession` maintains system prompt and handles structured output
- All dates are ISO-8601 with timezone (e.g., `2025-10-12T14:00:00+09:00`)

**Write-Only Calendar Access**:
- `CalendarService.requestWriteOnlyIfNeeded()` uses iOS 17+ `requestWriteOnlyAccessToEvents()`
- No read access required (privacy-first design)
- Default calendar is used for all events

**Timezone-Aware Date Handling**:
- `DateUtil` handles all ISO-8601 parsing/formatting with timezone context
- Current timezone is always passed to parser for context
- Default 60-minute duration applied if end time is omitted

## File Structure

```
T2C/
├── App/
│   └── T2CApp.swift              # App entry point with haptic setup
├── Views/
│   └── MainView.swift            # Single-screen UI
├── ViewModels/
│   └── MainViewModel.swift       # State machine + async intents
├── Services/
│   ├── NLParser.swift            # FoundationModels guided generation
│   └── CalendarService.swift    # EventKit write-only access + CalendarEvent model
└── Utilities/
    ├── DateUtil.swift            # ISO-8601 helpers, timezone handling
    └── HapticUtil.swift          # Haptic feedback suppression (simulator)
```

## Important Implementation Details

### FoundationModels Integration
- `ParsedEvent` struct defines the schema for model output via `@Generable` macro
- System prompt in `NLParser.init()` guides the model on date interpretation and field distribution
- Each request includes current date/time and timezone as context
- Model returns structured JSON matching `ParsedEvent` schema

### Date Parsing Rules (NLParser.swift:48-62)
- Time only → next occurrence from current time
- No end time → left empty (60-min default applied by ViewModel)
- Relative dates (tomorrow, next week) → interpreted from current date
- All dates must be ISO-8601 with timezone

### Calendar Permissions
- Required: `NSCalendarsWriteOnlyAccessUsageDescription` in Info.plist
- Only write-only access is requested (privacy-preserving)
- Permission flow handled in `CalendarService.requestWriteOnlyIfNeeded()`

### Error Handling
All services use `LocalizedError` for user-facing messages:
- `ParsingError.invalidDateFormat` - NLParser date parsing failure
- `CalendarError.permissionDenied` - Calendar access denied
- `CalendarError.saveFailed(Error)` - EventKit save failure

### Logging
Uses `OSLog` with structured logging:
- Subsystem: `com.t2c.app`
- Categories: `MainViewModel`, `NLParser`, `CalendarService`
- Info-level for state transitions, debug-level for intermediate steps

## Testing Strategy (Planned)

The project-overview.md specifies minimal testing:
- Unit tests: text → ISO-8601 parsing, default duration logic, timezone correctness
- UI tests: parse flow, preview rendering, save success path

No tests currently exist; tests should be added in future iterations.

## Edge Cases & UX Considerations

From project-overview.md:
- No date found → suggest quick chips (Today 6pm, Tomorrow 9am)
- Past time → nudge user to next day
- Ambiguous info → leave in appropriate field (title/notes), user can edit before save

## Development Notes

- Single-screen design: no navigation, all UI states handled via conditional rendering in MainView
- Haptics are disabled in simulator via `HapticUtil.disableKeyboardHaptics()`
- Default duration: 60 minutes (3600 seconds) in `DateUtil.defaultDuration`
- All async operations are marked with `@MainActor` for UI safety
