<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# Edison

## Purpose
Edison is a macOS menu-bar clipboard manager and screenshot capture/annotation tool. It runs as an `.accessory` process (no Dock icon), monitors the system clipboard, stores a history of up to 250 items (text, images, file URLs), and exposes a keyboard-driven "Hub" shelf window for browsing and acting on that history. Screenshots can be captured via global hotkeys and annotated in a lightweight editor before being saved or copied.

## Key Files

| File | Description |
|------|-------------|
| `Package.swift` | Swift Package Manager manifest — declares the `Edison` executable target and `EdisonTests` test target, requires macOS 14+ |
| `README.md` | Project overview and setup instructions |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Edison/` | All Swift source code, organized by domain (see `Edison/AGENTS.md`) |
| `docs/` | Design documents — architecture, product spec, UI style guide, constraints (see `docs/AGENTS.md`) |
| `scripts/` | CI and local-dev shell scripts (see `scripts/AGENTS.md`) |
| `Assets.xcassets/` | App-level asset catalog: app icon + menu-bar icon image sets |
| `icons/` | Source icon artwork (PNG originals used to generate `Assets.xcassets`) |
| `Edison.xcodeproj/` | Xcode project file — **do not edit manually**; managed by Xcode |

## For AI Agents

### Working In This Directory
- The project builds with either `swift build` (SPM) or Xcode.
- The primary source of truth for build configuration is `Package.swift`; `Edison.xcodeproj` mirrors it for IDE use.
- macOS 14 (Sonoma) is the minimum deployment target.
- The app requires Screen Recording and Accessibility permissions at runtime for capture and hotkey features.
- Bundle identifier placeholder `com.your-company.Edison` must be replaced before shipping (noted in `SettingsView.swift`).

### Testing Requirements
- Run tests: `swift test` from the repo root.
- Tests live in `Edison/Tests/EdisonTests.swift`.
- Tests use Swift Testing framework (with XCTest fallback).
- All tests are unit tests; no UI or integration tests exist yet.

### Common Patterns
- `AppState` is the single shared `ObservableObject` wired through the SwiftUI environment.
- Core services (clipboard, capture, search, persistence, hotkeys) are owned by `AppState` and initialized once.
- `@MainActor` is used on all UI-touching classes; background work uses `DispatchQueue` or structured concurrency.
- Prefer `final class` for services and `struct` for value types (models).

## Dependencies

### External
- No third-party Swift packages — pure Apple SDK dependencies only.

### Key Apple Frameworks
- `SwiftUI` — Hub, Settings, editor UI
- `AppKit` — menu bar, window management, clipboard, hotkeys, screen capture
- `Carbon` — global hotkey registration (`RegisterEventHotKey`)
- `ScreenCaptureKit` — planned native capture path (current: `screencapture` CLI)
- `UniformTypeIdentifiers` — file type handling in export/share flows

<!-- MANUAL: -->
