<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# UI

## Purpose
All SwiftUI views, themes, and reusable components. The UI layer is strictly presentational — it reads from and dispatches actions to `AppState` via `@EnvironmentObject`, but contains no business logic. Three sub-domains: the main Hub shelf window, the screenshot editor, and shared components (settings, shortcut editor row).

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Hub/` | The primary shelf window: `HubView` (clipboard history browser) and `HubTheme` (design tokens, glass background, window styling) (see `Hub/AGENTS.md`) |
| `EditorUI/` | `EditorWindowView` — screenshot annotation editor with crop, arrow, rectangle, and text tools plus undo/redo (see `EditorUI/AGENTS.md`) |
| `Components/` | Reusable views: `SettingsView` (keyboard shortcut settings form), `ShortcutEditorRow` (per-action shortcut binding row) (see `Components/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- All colors, radii, spacing, and sizing must come from `HubTheme` constants — never use raw magic numbers.
- Use `HubTheme.Space.x1–x6` for padding/spacing.
- Use `HubTheme.Radius.*` for corner radii.
- Glass backgrounds must use `HubGlassBackground` and respect `accessibilityReduceTransparency`.
- Accessibility: all interactive elements need labels; support both light and dark appearance.
- Do not add business logic to views — compute derived state in `AppState` instead.

### Testing Requirements
- No automated UI tests exist yet. Verify visually in the Simulator or on device.
- Unit-testable logic (e.g. computed layout values) should be extracted to `Core/` or `AppState`.

### Common Patterns
- `@EnvironmentObject private var appState: AppState` is the standard injection point.
- `HubTheme` static methods (`cardSize(for:)`, `accentColor(for:)`) customize cards by payload type.
- `HubShelfWindowStyle.apply(to:)` configures the Hub window as a floating, non-movable shelf at the bottom of the screen.

## Dependencies

### Internal
- `Core/Models/` — `ClipboardItem`, `ItemCollection`, `ClipboardPayload`
- `Core/Shortcuts/` — `ShortcutAction`, `Shortcut`, `ShortcutSet`, `ShortcutStore`
- `App/AppState` — shared state and all user actions

### External
- `SwiftUI`, `AppKit`

<!-- MANUAL: -->
