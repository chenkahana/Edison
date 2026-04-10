<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# Components

## Purpose
Reusable UI components shared across the app. Currently contains the Settings window and the per-action shortcut binding row used within it.

## Key Files

| File | Description |
|------|-------------|
| `SettingsView.swift` | macOS Settings window content — a `Form` with a "Keyboard Shortcuts" section (one `ShortcutEditorRow` per `ShortcutAction`) and an "About" section. Reads current shortcuts from `appState.shortcutStore` on appear and saves via `appState.save(shortcuts:)`. |
| `ShortcutEditorRow.swift` | A single row for editing one shortcut binding — stepper for keyCode (0–127) and checkboxes for ⌘/⇧/⌥/⌃ modifiers. Uses `Binding<Shortcut>` for two-way binding into the parent's editable shortcut set. |

## For AI Agents

### Working In This Directory
- `SettingsView` holds an `@State var editableShortcuts: ShortcutSet` local copy that is only written to `AppState` when the user taps "Save Shortcuts" — edits are not live.
- `ShortcutEditorRow` uses a `Stepper` to select key codes numerically (0–127 Virtual Key codes). A future improvement would be a key-capture field, but do not add that without a design spec.
- The Settings window width is fixed at 620 pt.
- The bundle identifier shown in "About" is a placeholder (`com.your-company.Edison`) — this must be replaced before shipping.
- Shortcut rows are generated from `ShortcutAction.allCases` — adding a new action automatically adds a row.

### Testing Requirements
- No automated tests. Verify that editing shortcuts and saving applies them system-wide (hotkeys fire).

### Common Patterns
- Modifier binding helper `modifierBinding(mask:)` in `ShortcutEditorRow` uses bitwise AND/OR on `shortcut.modifiers` — follow the same pattern for any new modifier toggles.

## Dependencies

### Internal
- `Core/Shortcuts/` — `ShortcutAction`, `Shortcut`, `ShortcutSet`, `ShortcutStore`
- `App/AppState` — `shortcutStore`, `save(shortcuts:)`

### External
- `SwiftUI`, `Carbon` (modifier key constants in `ShortcutEditorRow`)

<!-- MANUAL: -->
