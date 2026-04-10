<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# Core

## Purpose
All business logic and services, fully decoupled from SwiftUI views. Each subdirectory is a focused domain: data models, clipboard observation, screen capture, full-text search, disk persistence, and global hotkey management. `Core` types are pure Swift — they use AppKit where necessary (clipboard, screen capture) but carry no SwiftUI dependencies.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Models/` | Value types shared across the app: `ClipboardItem`, `ItemCollection`, `ClipboardPayload` (see `Models/AGENTS.md`) |
| `Clipboard/` | `ClipboardMonitor` (polls `NSPasteboard`) and `ImageProcessing` (resize + PNG conversion) (see `Clipboard/AGENTS.md`) |
| `Capture/` | `CaptureEngine` wraps `screencapture` CLI; `RegionSelectionSession` provides interactive area-select overlay (see `Capture/AGENTS.md`) |
| `Persistence/` | `HistoryStore` serializes clipboard history + collections to `~/Library/Application Support/Edison/history.json` (see `Persistence/AGENTS.md`) |
| `Search/` | `HistorySearchEngine` filters items by free-text query and payload type (see `Search/AGENTS.md`) |
| `Shortcuts/` | `ShortcutAction` enum, `Shortcut`/`ShortcutSet` models, `ShortcutStore` (UserDefaults), `HotKeyCenter` (Carbon hotkeys) (see `Shortcuts/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Keep all types here free of SwiftUI imports.
- Services are initialized and owned by `AppState` in `App/`; `Core` types do not reference `AppState`.
- Prefer structs for models (`ClipboardItem`, `ItemCollection`), `final class` for services (`ClipboardMonitor`, `HistoryStore`).
- Background work uses serial `DispatchQueue` (labeled `edison.<domain>.*`) — never block the main thread.

### Common Patterns
- Services expose a simple start/stop or load/save interface.
- Models conform to `Codable`, `Identifiable`, `Hashable` for persistence and SwiftUI list use.

## Dependencies

### External
- `AppKit` — clipboard, image handling, screen capture
- `Carbon` — hotkey registration
- `Foundation` — `Codable`, `UUID`, `Date`, file I/O

<!-- MANUAL: -->
