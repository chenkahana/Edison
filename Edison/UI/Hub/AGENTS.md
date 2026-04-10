<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# Hub

## Purpose
The main user-facing shelf window. `HubView` is a full-width, bottom-of-screen floating panel that displays clipboard history in three layout modes (Shelf/rail, List, Grid) with search, type filters, favorites, and collection management. `HubTheme` centralises all design tokens (colors, radii, spacing, sizes) and provides the glass-effect background and window-styling helpers.

## Key Files

| File | Description |
|------|-------------|
| `HubView.swift` | Root SwiftUI view for the Hub window — header bar (search pill, layout picker, type filter, collection sidebar controls), item grid/list/rail, preview pane, empty state, editor sheet |
| `HubTheme.swift` | Design token namespace (`HubTheme`) — spacing scale (x1–x6), corner radii, window size, card sizing per payload type, per-type accent colors, all semantic colors (glass, text, card fills). Also: `VisualEffectView` (NSViewRepresentable for blur), `HubGlassBackground` (composited glass look respecting `reduceTransparency`), `HubShelfWindowStyle` (positions window as non-movable shelf at screen bottom) |

## For AI Agents

### Working In This Directory
- **Never hardcode colors, spacing, or radii.** Use `HubTheme.*` constants exclusively.
- `HubShelfWindowStyle.apply(to:)` must be called on the Hub `NSWindow` to position it correctly — it is called both at window creation (`WindowRouter`) and on every `openHub()` call.
- Window size is `HubTheme.shelfWindowSize` (1440 × 360 pt); actual width expands to fill the screen's visible frame.
- Card dimensions vary by payload type — use `HubTheme.cardSize(for:)` and `HubTheme.accentColor(for:)`.
- `HubGlassBackground` handles `accessibilityReduceTransparency` — always use it as the window background rather than raw `Color` or `VisualEffectView`.
- The Hub window is `level = .floating`, non-movable, moves to active space, excluded from Exposé.
- Layout modes: `.rail` (horizontal scroll), `.list`, `.grid` (responsive column count via `gridColumnCount`).
- The preview pane (`HubTheme.previewPaneWidth` = 360 pt) is shown alongside the grid/list when an item is selected.

### Testing Requirements
- Visual testing only — preview in Xcode canvas or run the app.
- Verify glass effect on both light and dark appearance and with "Reduce Transparency" enabled in Accessibility settings.

### Common Patterns
- `HubFilter` (.all / .favorites) and `HubLayoutMode` (.rail / .list / .grid) are private enums local to `HubView`.
- `selectedItem` defaults to the first item in the filtered list when `selectedItemID` is nil or not found.
- `isFilteringActive` is used to show/hide a "clear filters" affordance.
- Color extensions: `Color(hex: 0xRRGGBB)` is a private convenience initializer in `HubTheme.swift`.

## Dependencies

### Internal
- `Core/Models/` — `ClipboardItem`, `ClipboardPayload`, `ItemCollection`
- `App/AppState` — all state and actions
- `UI/EditorUI/EditorWindowView` — presented as a sheet for screenshot annotation

### External
- `SwiftUI`, `AppKit`

<!-- MANUAL: -->
