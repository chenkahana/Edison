<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# Shortcuts

## Purpose
Global keyboard shortcut registration and persistence. `ShortcutModels` defines the data types; `ShortcutStore` persists the user's custom bindings to `UserDefaults`; `HotKeyCenter` registers them system-wide via the Carbon `RegisterEventHotKey` API and dispatches `ShortcutAction` callbacks.

## Key Files

| File | Description |
|------|-------------|
| `ShortcutModels.swift` | `ShortcutAction` (openHub, captureArea, captureWindow, captureFullScreen), `Shortcut` (keyCode + modifiers as `UInt32`), `ShortcutSet` (action→shortcut map with defaults) |
| `ShortcutStore.swift` | Reads/writes `ShortcutSet` from `UserDefaults` under key `"edison.shortcuts.v1"` using JSON coding |
| `HotKeyCenter.swift` | Singleton that installs a Carbon event handler, registers `EventHotKeyRef` entries for each action, and calls a stored callback when a hotkey fires |

## For AI Agents

### Working In This Directory
- `HotKeyCenter` is a singleton (`HotKeyCenter.shared`) — only one instance exists for the lifetime of the app.
- Calling `apply(shortcuts:)` unregisters all previous hotkeys before registering new ones — it is safe to call repeatedly.
- The Carbon handler signature code is `"EDSN"` (four-char code). IDs are assigned as `index + 1` from `ShortcutAction.allCases`.
- Default shortcuts: Open Hub = ⌘⇧V, Capture Area = ⌘⇧2, Capture Window = ⌘⇧3, Capture Full Screen = ⌘⇧4.
- Adding a new `ShortcutAction` case automatically participates in hotkey registration (it's enumerated via `allCases`) — also add a default entry in `ShortcutSet.default`.
- `UserDefaults` key is versioned (`v1`) — if the data model changes, increment the version and handle migration in `ShortcutStore.current`.

### Testing Requirements
- Not unit-testable without a running macOS process (Carbon APIs require an application event target).
- Test new actions manually by changing shortcuts in Settings and verifying the hotkey fires.

### Common Patterns
- `ShortcutSet` subscript (`shortcuts[action]`) defaults to `Shortcut.defaultOpenHub` if the action is missing from the map — ensure all actions always have entries in `ShortcutSet.default`.

## Dependencies

### External
- `Carbon` — `RegisterEventHotKey`, `GetApplicationEventTarget`, `InstallEventHandler`
- `AppKit`, `Foundation`

<!-- MANUAL: -->
