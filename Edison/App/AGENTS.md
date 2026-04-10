<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# App

## Purpose
Process lifecycle and application-level wiring. This directory owns the SwiftUI `App` entry point, the `NSApplicationDelegate`, the single shared `AppState` observable object, the menu-bar status item, and the `WindowRouter` that opens/closes the Hub and Settings windows. Nothing in this layer contains pure business logic — it delegates to `Core/` services.

## Key Files

| File | Description |
|------|-------------|
| `EdisonApp.swift` | `@main` SwiftUI App struct — declares the Hub `Window` scene and the `Settings` scene; wires `AppDelegate` via `@NSApplicationDelegateAdaptor` |
| `AppState.swift` | Central `@MainActor ObservableObject` that owns all services, drives filtered/searched item lists, and handles all user actions (copy, export, share, favorite, collections, screenshot capture) |
| `AppDelegate.swift` | `NSApplicationDelegate` — sets activation policy to `.accessory`, creates `StatusBarController` |
| `StatusBarController.swift` | Manages the menu-bar `NSStatusItem` and its dropdown menu (Open Hub, Capture, Settings, Quit) |
| `WindowRouter.swift` | Resolves and presents the Hub window (`NSWindow` level `.floating`, positioned at bottom of screen); also triggers the Settings window via `showSettingsWindow:` |

## For AI Agents

### Working In This Directory
- `AppState` is the single source of truth for UI state. Extend it when a new feature needs shared mutable state.
- `AppState` suppresses clipboard monitoring feedback loops via `suppressedClipboardPayloads` — any action that writes to the pasteboard must insert into this set first.
- History is capped at 250 items (`historyLimit`); enforce this wherever new items are added.
- `WindowRouter` uses a multi-fallback resolution strategy to find the Hub window — do not add a new window identity scheme without updating `resolveHubWindow()`.
- The app has no Dock icon (`NSApp.setActivationPolicy(.accessory)`). Use `NSApp.activate(ignoringOtherApps: true)` before showing any window.

### Testing Requirements
- `AppState` logic (filtering, collections, favorites) is testable without UI — consider unit tests in `Tests/`.
- `WindowRouter` and `StatusBarController` require a running `NSApplication` and are not unit-testable in isolation.

### Common Patterns
- All `AppState` methods are `@MainActor`; call from async contexts with `Task { @MainActor in ... }`.
- Notification-based communication: `CaptureEngine` posts `.edisonScreenshotCaptured`; `AppState` observes it.
- `filteredItems` is a computed property that composes search query + type filter + collection filter.

## Dependencies

### Internal
- `Core/Models/` — `ClipboardItem`, `ItemCollection`, `ClipboardPayload`
- `Core/Clipboard/` — `ClipboardMonitor`, `ImageProcessing`
- `Core/Capture/` — `CaptureEngine`
- `Core/Persistence/` — `HistoryStore`
- `Core/Search/` — `HistorySearchEngine`
- `Core/Shortcuts/` — `ShortcutStore`, `HotKeyCenter`
- `UI/Hub/` — `HubView`, `HubTheme`
- `UI/Components/` — `SettingsView`

### External
- `AppKit`, `SwiftUI`, `Combine`, `UniformTypeIdentifiers`

<!-- MANUAL: -->
