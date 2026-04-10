# Architecture Direction

## App structure
- Menu bar app shell with Hub + Settings
- Shared app state coordinates clipboard, capture, search, and persistence
- Unified history model for clipboard and screenshot items

## SwiftUI vs AppKit
- **SwiftUI:** Hub, Settings, editor UI
- **AppKit:** status item/menu bar integration, hotkeys, macOS-specific window/capture behaviors

## Persistence direction
- Local-only, simple file/UserDefaults persistence
- Keep read/write safe and non-blocking
- No database migration project unless required by blockers

## Screenshot direction
- Native-first final direction is **ScreenCaptureKit**
- Temporary fallback path is acceptable until full native capture/editor integration is complete

## Simplicity rules
- Prefer direct implementation over abstractions
- Add layers only when current code blocks delivery
