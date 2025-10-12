# T2C

A minimal iOS app that converts natural language text into calendar events using on-device LLM.

## Description

T2C lets you create calendar events by typing natural language like "Lunch with Alex next Tue 1pm @Shibuya". The app uses FoundationModels for on-device parsing and write-only EventKit access for privacy-preserving calendar integration.

## Requirements

- iOS 17+ (for write-only calendar access)
- Xcode 15+
- Swift 5.9+

## Build

```bash
xcodebuild -project T2C.xcodeproj -scheme T2C -configuration Debug build
```

## Architecture

Three-layer design:
- **UI Layer**: SwiftUI single-screen interface
- **Business Logic**: State machine orchestration (`MainViewModel`)
- **Services**: `NLParser` (FoundationModels guided generation), `CalendarService` (EventKit)

## Key Features

- On-device LLM with guided generation (`@Generable` macro)
- Write-only calendar access (no read permissions)
- Timezone-aware ISO-8601 date handling
- Privacy-first design

## License

MIT
