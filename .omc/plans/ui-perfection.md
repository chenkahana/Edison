# UI Perfection Plan — Edison → Paste-level Quality

**Created:** 2026-04-10  
**Scope:** All UI improvements to bring Edison to Paste-level visual and interaction quality  
**Reference:** Paste app (pasteapp.io), `docs/ui-style-guide.md`, Edison UI audit

---

## Requirements Summary

Paste's premium feel rests on four pillars that Edison is missing or under-implementing:
1. **Correct glass material** — existing implementation uses ~0.18 alpha vs the 0.52 spec
2. **Content-first cards** — source app icon + name, rich metadata, hex color swatches, formatted text previews
3. **Full interaction model** — Quick Look, direct paste, drag-out, delete, multi-select, hover states, animations
4. **Window quality** — NSPanel, open/close animation, resizable shelf, collection colors

---

## Acceptance Criteria

- [ ] Glass base alpha matches style guide spec (0.52 light / 0.58 dark) — visually measurable
- [ ] Every card shows source app icon at 16×16 in header area and app name label in `meta.card` typography
- [ ] Space key opens system QLPreviewPanel for selected item
- [ ] Return key and double-click paste item directly into the previously-active app (with AX permission) or copy + notify (without)
- [ ] Right-click context menu includes Delete action that removes item from history with undo toast
- [ ] Cards respond to hover with 1.015 scale + elevated shadow within `anim.fast` (0.12s) spring
- [ ] Shelf slides up with `anim.standard` (0.20s easeInOut) on open, slides down on dismiss
- [ ] Shelf top-edge drag handle resizes window height between 156–480pt and persists across sessions
- [ ] Cards display character count (text), image dimensions (image), or file size (file) in footer area
- [ ] Hex color text items (`#RRGGBB` / `#RGB`) render a color swatch in the card body
- [ ] Drag from a card into any app delivers the correct NSItemProvider payload (text/image/file)
- [ ] Cmd+click / Shift+click selects multiple cards; context menu and detail pane handle multiple selections
- [ ] ItemCollection gains an optional `accentColor` (hex string); collection picker and cards show it
- [ ] Animation tokens (`anim.fast`, `anim.standard`, `anim.emphasis`, spring curve) defined in `HubTheme`
- [ ] Two-layer shadow (`shadow.key` + `shadow.ambient`) applied to cards per style guide
- [ ] Shelf uses `NSPanel` instead of `NSWindow`
- [ ] All states verified under Reduce Transparency and dark/light appearance

---

## Implementation Steps

### Phase 1 — Token & Foundation Fixes (non-visible prerequisite for everything else)

**1.1 Fix glass color tokens in `HubTheme.swift`**  
File: `Edison/UI/Hub/HubTheme.swift` lines 51–94  
- `glassBase`: change light alpha `0.18 → 0.52`, dark `0.22 → 0.58`
- `glassTintWarm`: change both alphas `0.02 → 0.10`
- `glassStroke` light: `0.14 → 0.26` (dark stays 0.08→0.14 per style guide)
- `cardFill` light: `0.18 → 0.22` (slight bump for card legibility over brighter background)
- Add `HubTheme.glassHighlight`: top-edge linear gradient per style guide (`0.22→0.00` light, `0.10→0.00` dark)

**1.2 Add animation tokens to `HubTheme.swift`**  
After existing constants, add:
```swift
enum Anim {
    static let fast: Double = 0.12
    static let standard: Double = 0.20
    static let emphasis: Double = 0.28
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.82, blendDuration: 0)
}
```

**1.3 Add two-layer shadow helpers to `HubTheme.swift`**  
Replace `cardShadow(colorScheme:)` with:
```swift
static func cardShadowKey(colorScheme: ColorScheme) -> Color  // 0.18 light / 0.55 dark
static func cardShadowAmbient(colorScheme: ColorScheme) -> Color  // 0.08 light / 0.30 dark
```
Card views update to apply both: ambient (radius 10, y 2) + key (radius 28, y 10, x -6).

**1.4 Migrate shelf window from `NSWindow` to `NSPanel`**  
Files: `Edison/App/WindowRouter.swift`, `Edison/App/AppDelegate.swift`, `EdisonApp.swift`  
- Replace `Window("Edison", id: "hub")` scene with a custom `NSPanel` created in `AppDelegate` / `WindowRouter`
- Panel config: borderless, `isFloatingPanel = true`, `becomesKeyOnlyIfNeeded = true`
- `HubShelfWindowStyle.apply(to:)` updated to target `NSPanel`
- The SwiftUI view is hosted via `NSHostingView` in the panel's `contentView`

**1.5 Add shelf open/close animation**  
File: `Edison/App/WindowRouter.swift`  
- `openHub()`: set frame to off-screen-below first, then animate frame to final position with `NSAnimationContext` duration `HubTheme.Anim.standard`, `timingFunction: .easeInOut`
- `dismissHub()`: animate frame down off-screen, then `orderOut` on completion

---

### Phase 2 — Card Quality Improvements

**2.1 Show source app name on cards**  
File: `Edison/UI/Hub/HubView.swift` — `HubShelfCardView`, `HubListRowView`, `HubDetailView`  
- In `HubShelfCardView` footer row: add `Text(item.sourceApplication?.localizedName ?? "")` at `meta.card` (10pt regular) in `textTertiary`, truncated to 1 line, max width ~80pt
- In `HubListRowView`: add app name beside the kind chip
- In `HubDetailView`: add a `LabeledContent("Source", value: name)` row below the kind chip

**2.2 Show source app icon prominently in card header**  
File: `Edison/UI/Hub/HubView.swift` — `HubShelfCardView`  
- Current: app icon used only as the kind chip icon at 12pt
- Change: add a dedicated 20×20 `HubItemIconView` in the top-right corner of the card (overlay, `.topTrailing` alignment), with a subtle `cardFillMuted` circular background (26×26), separate from the kind chip
- Kind chip retains SF Symbol for type; app icon moves to the dedicated badge slot

**2.3 Add metadata footer to cards**  
File: `Edison/UI/Hub/HubView.swift` — `HubShelfCardView`, `HubDetailView`  
- Text items: compute character count in `AppState` or as a computed property on `ClipboardItem`; display `"\(count) chars"` in footer at `meta.card`
- Image items: read `CGImageSource` dimensions from `ClipboardImageData.data` (lazy, cached); display `"1920 × 1080"` in footer
- File items: `URLResourceValues.fileSize`; display `"2.3 MB"` in footer
- Absolute timestamp: add `.help(item.createdAt.formatted(date: .long, time: .standard))` tooltip on the relativeTimestamp label

**2.4 Hex color swatch detection**  
File: `Edison/UI/Hub/HubView.swift` — preview area in `HubShelfCardView`  
- Detect when `payload == .text(let s)` and `s.trimmingCharacters(in: .whitespaces)` matches `^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$`
- If match: render the card preview area as a solid `Color(hex:)` swatch (full card body height) with the hex string label centered in white/black (contrast-adaptive)
- Extract to `HubHexColorView` sub-view

**2.5 Formatted text rendering in cards**  
File: `Edison/UI/Hub/HubView.swift` — text preview fallback in `HubShelfCardView`  
- Current: renders first 3 lines of plain text in a `Text` view
- If clipboard item has a `.text` payload where the string contains RTF markers or markdown, render with `AttributedString` (from `NSAttributedString(rtf:documentAttributes:)`)
- Fallback gracefully to plain text if parsing fails
- Cap at 3 lines; apply `meta.card` sizing

---

### Phase 3 — Interactions

**3.1 Quick Look (Space key)**  
File: `Edison/UI/Hub/HubView.swift`  
- In the `HubWindowAccessor` key monitor, handle `keyCode == 49` (space)
- Show `QLPreviewPanel.shared()` for the selected item
- Implement `QLPreviewPanelDataSource` (item count = 1, `previewItemAtIndex` returns a `URL` for file items, or a temp file written from `Data` for text/image items)
- Panel dismisses on next Space or Escape

**3.2 Direct paste into active app**  
File: `Edison/App/AppState.swift`  
- New method `pasteItem(itemID: UUID)`
- Before opening hub: record `NSWorkspace.shared.frontmostApplication` as `lastActiveApp`
- `pasteItem`: call `copyToClipboard(itemID:)`, then use `AXUIElementCreateApplication(pid)` to send `⌘V` via `CGEvent` post to the recorded app's process
- If AX permission not granted (`AXIsProcessTrusted()` returns false): fall back to `copyToClipboard` + show a brief in-shelf toast: "Copied — paste with ⌘V (grant Accessibility for auto-paste)"
- Trigger on: Return key in HubView key monitor, double-click on card
- `WindowRouter.dismissHub()` is called after paste

**3.3 Delete from history**  
File: `Edison/App/AppState.swift`, `Edison/UI/Hub/HubView.swift`  
- Add `deleteItem(itemID: UUID)` to `AppState`: removes from `historyItems`, cleans up collection references, persists
- Add to context menu (Primary group): "Delete" with `trash` SF Symbol, destructive role
- Add keyboard shortcut: `Delete` key in key monitor when item is selected
- Show a brief undo toast for 4s: "Removed — Undo" that calls `undoDelete(item:)`; after 4s, toast disappears and delete is permanent

**3.4 Hover state animations on cards**  
File: `Edison/UI/Hub/HubView.swift` — `HubShelfCardView`  
- Add `@State private var isHovered = false`
- `.onHover { isHovered = $0 }` on the card
- `scaleEffect(isHovered || isSelected ? 1.015 : 1.0).animation(HubTheme.Anim.spring, value: isHovered)`
- Shadow depth: ambient shadow stays, key shadow `y` increases from 10 → 16 on hover
- Transition duration: `HubTheme.Anim.fast` (0.12s)

**3.5 Drag-out from cards**  
File: `Edison/UI/Hub/HubView.swift` — `HubShelfCardView`  
- Add `.draggable(item)` modifier using `Transferable` conformance on `ClipboardItem`
- Implement `Transferable` on `ClipboardItem` in `Core/Models/ClipboardItem.swift`:
  - `.text` → `NSPasteboardWriting` / `String` transfer representation
  - `.image` → `NSImage` / PNG `Data`
  - `.fileURL` → `URL` file representation
- Drag preview: `ContentShape(Rectangle())` at card bounds with scale 1.02 and elevated shadow during drag
- On drag start: `isHovered = true` kept until drag ends

**3.6 Multi-select**  
File: `Edison/UI/Hub/HubView.swift`, `Edison/App/AppState.swift`  
- Replace `@State private var selectedItemID: UUID?` with `@State private var selectedItemIDs: Set<UUID>`
- Cmd+click: toggle item in/out of selection
- Shift+click: range select from anchor to clicked item
- When `selectedItemIDs.count > 1`: detail pane shows multi-select summary ("N items selected") with bulk actions: Copy All, Delete All, Add to Collection
- Context menu adapts to show plural actions when multiple items selected

**3.7 Quick-paste number badges (Cmd+1–9)**  
File: `Edison/UI/Hub/HubView.swift` — `HubShelfCardView`  
- When shelf is open and no search is active, overlay badge `"⌘1"` through `"⌘9"` on the first 9 cards in `meta.card` (10pt medium) in the top-left corner of each card, on a `cardFillMuted` capsule background
- In key monitor: intercept `.command + 1–9` (keyCodes 18–26), call `pasteItem(itemID:)` on the matching index item
- Badge fades in/out with the shelf using `anim.fast`

---

### Phase 4 — Window & Collection Polish

**4.1 Resizable shelf**  
File: `Edison/App/WindowRouter.swift`, `Edison/UI/Hub/HubView.swift`  
- Add a 20pt drag handle strip at the very top of the shelf (above the header): a subtle `HubTheme.dividerOnGlass`-colored horizontal bar with a 24pt wide `capsule` grab indicator in `textTertiary`
- Track drag with `DragGesture(coordinateSpace: .global).onChanged { ... }` updating window height
- Clamp height to `156...480` pt
- Persist chosen height to `UserDefaults` key `"edison.shelfHeight"`, restore on `HubShelfWindowStyle.apply`

**4.2 Collection accent colors**  
File: `Edison/Core/Models/Collection.swift`, `Edison/App/AppState.swift`, `Edison/UI/Hub/HubView.swift`  
- Add `var accentHex: String?` to `ItemCollection`
- In the collection creation flow (inline name field in HubView header): add a color well (`ColorPicker` in SwiftUI or a row of 6 preset swatches) to pick the accent
- Collection tab/capsule in the header adopts the accent color as its background tint
- Cards in a filtered collection view show a 2pt left border in the collection accent color instead of the type accent pill
- Search result cards show a small colored dot indicating their source collection

**4.3 Keyboard-recording shortcut editor**  
File: `Edison/UI/Components/ShortcutEditorRow.swift`  
- Replace the Stepper + checkbox row with an `NSViewRepresentable` wrapping `NSTextField` subclass that:
  - Shows human-readable key description (`"⌘⇧V"`) when not focused
  - On focus/click, enters recording mode, captures the next key event, displays symbols live
  - On Escape, reverts; on Enter or loss of focus, commits
- Use `Carbon.h` `UCKeyTranslate` to convert `keyCode → character` for display

---

### Phase 5 — Accessibility & Robustness

**5.1 VoiceOver labels on all card actions**  
File: `Edison/UI/Hub/HubView.swift`  
- Add `.accessibilityLabel`, `.accessibilityValue`, `.accessibilityHint` to each card
- Format: label = `"[type] from [app]"`, value = `"copied [relative time]"`, hint = `"double tap to paste"`
- Add `.accessibilityAction(named: "Paste") { ... }`, `.accessibilityAction(named: "Delete") { ... }`

**5.2 Reduce Transparency robustness**  
File: `Edison/UI/Hub/HubTheme.swift`  
- Update `opaqueFallback` light: `rgba(242,242,242,1)` → `Color(NSColor.windowBackgroundColor)` (adapts to OS version)
- Verify `HubGlassBackground` uses `opaqueFallback` for **all** glass surfaces under reduce-transparency, not just the outer shell

**5.3 Large text / Dynamic Type**  
File: `Edison/UI/Hub/HubView.swift`  
- Replace hardcoded `.font(.system(size: 12))` calls with `.font(.caption)`, `.font(.caption2)`, `.font(.footnote)` system style equivalents so they scale with accessibility font sizes

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| `NSPanel` + SwiftUI `Window` scene incompatibility | High — may break scene-based setup | Migrate Hub to AppKit-hosted panel in `AppDelegate`; keep `Settings` as SwiftUI scene |
| AX paste requires user permission dialog | Medium — degrades gracefully | Detect permission at startup, prompt once, always have copy fallback |
| `QLPreviewPanel` requires temp files for non-URL items | Low | Write temp files to `FileManager.default.temporaryDirectory`, clean up on panel close |
| Shelf resize conflicts with fixed `shelfWindowSize` constant | Low | Replace constant with `UserDefaults`-backed stored property |
| `Transferable` on `ClipboardItem` drag may interfere with existing copy-to-clipboard | Low | Use separate drag path; `copyToClipboard` unchanged |
| Glass alpha bump (0.18→0.52) may look too opaque on some wallpapers | Medium | Test on 5+ wallpaper types; add `glass.baseOpacity` user preference if needed |
| RTF parsing of arbitrary clipboard text strings may crash | Low | Wrap in `try?`, fallback to plain text |

---

## Verification Steps

1. **Glass check:** Open shelf over a colorful wallpaper — background should be clearly visible but diffused. Screenshot and compare alpha visually to Paste.
2. **Source app:** Copy from Safari, Terminal, Xcode. Verify correct icon + "Safari" / "Terminal" / "Xcode" label appears on each card.
3. **Quick Look:** Select a text item, press Space — QLPreviewPanel opens. Select an image, press Space — full-res image shown. Press Escape — panel closes.
4. **Direct paste:** Grant AX permission. Copy text from Notes. Open Edison, select item, press Return. Verify text appears in Notes.
5. **Delete + undo:** Right-click item → Delete. Item disappears. Click "Undo" in toast within 4s. Item reappears at correct position.
6. **Hover animation:** Hover over cards — spring scale to 1.015 with shadow lift, snaps back on mouseout.
7. **Shelf animation:** Trigger open (⌘⇧V) — shelf slides up from bottom. Press Escape — slides back down.
8. **Resize:** Drag top edge of shelf up → shelf grows to max 480pt; drag down → shrinks to min 156pt. Reopen shelf — height persists.
9. **Hex swatch:** Copy `#FF9400` from a text editor. Open Edison — card body is a solid orange swatch.
10. **Drag out:** Drag a text card into TextEdit — text is inserted. Drag image card into Finder — PNG file created.
11. **Multi-select:** Cmd+click 3 items — all highlighted. Context menu shows "Delete 3 Items".
12. **Quick paste:** Open shelf, press Cmd+1 — first item is pasted into last active app. Shelf closes.
13. **Reduce Transparency:** System Prefs → Accessibility → Reduce Transparency ON. Shelf uses opaque background. All text readable.
14. **VoiceOver:** Enable VoiceOver, navigate to shelf — cards announce content type, source app, copy time.
15. **Collection color:** Create collection "Design" with orange accent — collection tab shows orange tint; filtered cards show orange left border.

---

## File Change Index

| File | Changes |
|---|---|
| `Edison/UI/Hub/HubTheme.swift` | Fix glass alphas, add `Anim` enum, add two-layer shadow helpers, add `glassHighlight` |
| `Edison/UI/Hub/HubView.swift` | Source app badge, metadata footer, hex swatch, hover animations, Quick Look, Space/Return/Delete key handling, drag `.draggable`, multi-select, Cmd+1–9 badges, resize handle, VoiceOver labels |
| `Edison/App/AppState.swift` | `pasteItem()`, `deleteItem()`, `undoDelete()`, `lastActiveApp` tracking, metadata computed properties (char count) |
| `Edison/App/WindowRouter.swift` | NSPanel migration, animated open/close, height persistence |
| `Edison/App/AppDelegate.swift` | NSPanel construction, remove `Window` scene dependency for Hub |
| `EdisonApp.swift` | Remove Hub `Window` scene (replaced by AppKit panel); keep `Settings` scene |
| `Edison/Core/Models/ClipboardItem.swift` | `Transferable` conformance for drag support, computed `characterCount` |
| `Edison/Core/Models/Collection.swift` | Add `accentHex: String?` field |
| `Edison/UI/Components/ShortcutEditorRow.swift` | Replace Stepper+checkbox with key-recording NSViewRepresentable |

---

## ADR — Architecture Decision Record

**Decision:** Migrate Hub window from SwiftUI `Window` scene to an AppKit-owned `NSPanel` with SwiftUI content hosted via `NSHostingView`.

**Drivers:**
1. `NSPanel` enables `becomesKeyOnlyIfNeeded`, correct floating behavior, and fine-grained window control needed for drag-out, resize, and animated show/hide — none of which are controllable through SwiftUI `Window` scene.
2. Style guide explicitly mandates `NSPanel`.
3. Animations (slide-up/down) require frame manipulation that SwiftUI scene lifecycle does not expose.

**Alternatives considered:**
- *Keep SwiftUI `Window` scene + `WindowRouter` hacks:* Already at the limit of what's feasible — slide animation, resize, and panel behavior are blocked.
- *Full AppKit window with no SwiftUI:* Maximum control but throws away all existing SwiftUI card code; disproportionate churn.

**Why chosen:** Hybrid AppKit panel + SwiftUI `NSHostingView` content is the standard macOS pattern for premium utilities (1Password, Alfred, Raycast, Paste all use it). It gives full control over window behavior while preserving all SwiftUI view code.

**Consequences:**
- `EdisonApp.swift` no longer uses a SwiftUI `Window` scene for the Hub — requires removing that scene declaration and moving creation to `AppDelegate`.
- SwiftUI `@Environment(\.openWindow)` calls in `HubView` must be replaced with direct `WindowRouter` calls.
- `Settings` scene stays as SwiftUI `Settings { ... }` — unaffected.

**Follow-ups:**
- After NSPanel migration, evaluate whether ScreenCaptureKit capture can be triggered without the panel losing key status.
- Evaluate Paste Stack mode as a Phase 6 addition using a second small `NSPanel`.

---

*Saved: `.omc/plans/ui-perfection.md`*
