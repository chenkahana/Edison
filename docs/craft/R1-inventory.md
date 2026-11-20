# R1 Inventory

Every surface, its states, how it opens and closes, and its keyboard paths. Derived from `origin/main` `f59abfe`
code; rows marked **verify live** need the R0 session to confirm what the user actually sees. Transition curves are
quoted from code.

## Surfaces

| ID | Surface | Owner (code) | Window type |
|---|---|---|---|
| S1 | Menu bar item and menu | `App/StatusBarController.swift` | `NSStatusItem` + `NSMenu` |
| S2 | Hub shelf (rail, list, grid layouts) | `UI/Hub/HubView.swift`, `HubShelfView.swift`, `HubListView.swift` | `NSWindow` `[.titled, .fullSizeContentView]`, level `.floating`, full display width × 278 pt at the bottom of the visible frame (`HubTheme.swift:179-214`) |
| S3 | Detail / preview (Quick Look) | `HubSupportViews.swift:500-547` | System `QLPreviewPanel` (no in-Hub detail pane exists) |
| S4 | Search (header pill, type-to-search) | `HubHeaderView.swift:70-87`, `HubSupportViews.swift:421-461` | In Hub |
| S5 | Collections (picker, composer, delete) | `HubHeaderView.swift:142-191`, context menu `HubSupportViews.swift:232-245` | In Hub |
| S6 | Capture overlay (area, window, display) | `Core/Capture/CaptureEngine.swift:266-636` | One borderless `NSWindow` per display, level `.screenSaver` |
| S7 | Screenshot editor | `UI/EditorUI/EditorWindowView.swift` | Titled, resizable `NSWindow` 1120×760, min 920×620, autosaved frame (`AppDelegate.swift:95-108`) |
| S8 | Settings | `UI/Components/SettingsView.swift`, `App/EdisonApp.swift` | SwiftUI `Settings` scene, fixed 960×720 `NavigationSplitView` |
| S9 | Onboarding and permission prompts | `CaptureCoordinator.swift:212-224`, `HubView.swift:178-185`, `SettingsView.swift:316-345` | `NSAlert` (app-modal) and SwiftUI `.alert` |
| S10 | Share and export | `AppState.swift:455-496,582-600` | `NSSavePanel` (sheet in Hub, app-modal in editor), `NSSharingServicePicker` |
| S11 | Transient feedback (undo toast, capture error banner) | `HubView.swift:207-241`, `HubSupportViews.swift:119-191` | In Hub |

## States per surface

| Surface | States in code | Missing states (vs rubric check 10) |
|---|---|---|
| S1 | Normal; paused (icon `appearsDisabled`, tooltip, item title flips) | Capture in progress; permission missing; update available |
| S2 | Loading (no explicit state, history loads async `AppState.swift:216-224`); empty history; filtered empty; populated; paused pill; paste in flight (`isPasteInFlight`); Cmd held (⌘1–9 badges) | Loading placeholder (empty state likely flashes during `History Load`, **verify live**); Favorites-empty (shows "No History Yet", `HubView.swift:59-63`); collection-empty (shows search copy); huge item; unsupported type; image still loading |
| S3 | Text (temp `.txt`), image (temp `.png`), file (original URL) | Link preview; rich text preview (QL shows plain `.txt`, loses formatting) |
| S4 | Empty; typed via bridge; focused field (⌘F); results; no results | Match highlighting; token help beyond placeholder; Esc-clears-query |
| S5 | No collections (context submenu hidden); collection selected (trash visible); composer empty/disabled | Empty collection copy; rename; reorder; confirm delete; keyboard assign/jump |
| S6 | Area (idle, dragging with badge); window (hover highlight); display (F); cancelled; permission denied (before overlay) | Crosshair cursor, loupe, pointer coordinates, capture sound/flash, failure feedback when the Hub is closed |
| S7 | No screenshot (`ContentUnavailableView`); session; tool selected (11 tools); annotation selected; text editing; crop draft; unsaved changes alert | Zoom states; saving in progress; save failure inline |
| S8 | 7 panes; search filter; permission cards (granted / needs attention); launch-at-login status + error; shortcut conflicts | Remembered pane; confirmation for Clear History and Restore All Defaults; live permission refresh |
| S9 | Screen Recording alert (on first denied capture); Accessibility alert (on first denied paste); Settings permission cards | First-run onboarding; post-grant recovery (Screen Recording needs relaunch); in-context explanation before the system prompt |
| S10 | Export save panel; share picker; editor save panel; error alerts | Progress for large files; share anchored at the item |
| S11 | Undo toast 4 s (`ClipboardCoordinator.swift:239`); capture error banner (always offers "Screen Recording") | Keyboard undo (⌘Z) in the Hub; error-specific actions |

## Entry and exit transitions

| Surface | Entry | Exit | Motion (code) | Reduce Motion |
|---|---|---|---|---|
| S1 menu | Click status item | Choose item / click away | System | System |
| S2 Hub | ⇧⌘V (Carbon hotkey), status menu "Open Hub", app reopen (`AppDelegate.swift:124-128`) | Esc, ⇧⌘V again, losing key (`HubSupportViews.swift:341-347`), paste (instant), close via router | In: frame slide from below visible frame, 0.20 s `easeInEaseOut`, key after completion (`WindowRouter.swift:233-253`). Out: 0.18 s slide (`WindowRouter.swift:255-273`). Paste: instant `orderOut` + `NSApp.hide` (`WindowRouter.swift:164-167`) | Ignored |
| S2 content | Filter/search/collection/layout change | — | None: content swaps | — |
| S2 selection | Arrow keys, click | — | Selection fill/stroke snap; scroll follows with `easeInOut 0.16` (`HubView.swift:485`) | Ignored |
| S2 card insert/delete | New copy, delete, undo | — | None | — |
| S3 Quick Look | Space | Space/Esc in panel | System zoom; the Hub may dismiss when the panel takes key (`HubSupportViews.swift:341-347`), **verify live** | System |
| S6 overlay | ⇧⌘S, menu, capture shortcuts | Mouse up, click, F, Esc | Instant order front/out; frozen snapshot appears at once | — |
| S7 editor | After capture (default), ⌘E on image, menu "Edit Last Screenshot" | Done/Esc (discard alert if unsaved), ⌘↩ (copy + close), close button | System window order front; no transition from capture to editor | System |
| S8 Settings | Status menu "Settings" (⌘, while menu open) | Close button / ⌘W | System | System |
| S11 toasts | Delete; capture error | 4 s timer; dismiss button | `move(edge:) + opacity`, untokenised `spring(0.3, 0.8)` (`HubView.swift:218-220,238-239`) | Ignored |

## Keyboard paths

### Hub (handled by the `HubWindowAccessor` bridge before SwiftUI, `HubSupportViews.swift:371-451`)

| Key | Action | In a menu with shortcut shown? |
|---|---|---|
| ← → ↑ ↓ | Move selection (grid: rows by column count) | No |
| Return / Enter | Paste selected (source formatting) | Context menu "Paste", no shortcut shown |
| ⇧Return | Paste as plain text (text items only; silently ignored otherwise) | Context menu, ⇧↩ shown |
| ⌘1–⌘9 | Quick paste item N (badges while ⌘ held) | No |
| Printable characters (no ⌘/⌥/⌃) | Append to search | — |
| Space | Quick Look (also blocks typing a space into search) | No |
| Delete / Forward Delete | Delete last search character | — |
| ⌘⌫ | Delete selected item | Context menu "Delete", no shortcut shown |
| ⌘F | Focus search field | No |
| ⌘E | Annotate image | Context menu, ⌘E shown |
| ⌘O | Open link / Show in Finder / edit image | Context menu, ⌘O shown |
| Esc | Dismiss Hub (even with a query) | No |
| ⌘Z | Nothing (undo delete is mouse-only) | — |
| Tab | Not handled: falls to SwiftUI focus, header controls only (**verify live**) | — |
| ⌘C | Not handled in the bridge (**verify live** whether it copies the item) | Context "Copy", no shortcut |

### Capture overlay (`CaptureEngine.swift:366-417`)

| Key | Action |
|---|---|
| Drag | Area |
| Space | Toggle area/window (resets an in-progress drag) |
| F | Capture the display under the pointer |
| Esc | Cancel |
| Shift/Option while dragging | Nothing (macOS constrains/centres) |

### Editor (`EditorWindowView.swift:646-711` and button shortcuts)

| Key | Action |
|---|---|
| V A L R O P H T N B C | Select, Arrow, Line, Rectangle, Ellipse, Pen, Highlighter, Text, Step Counter, Pixelate, Crop |
| ⌘Z / ⇧⌘Z | Undo / Redo |
| ⌘C | Copy (stays open unless "Close After Copy or Save") |
| ⌘↩ | Copy and close |
| ⌘S | Save as PNG (app-modal panel) |
| Esc | Clear crop/selection, otherwise Done (`.cancelAction`) |
| ⌫ | Delete selected annotation |
| Arrows / ⇧Arrows | Nudge 1 / 10 pt |
| ⌘D | Duplicate |
| ⌘[ / ⌘] | Size down / up |
| Shift while drawing | 45° lines, squares/circles |
| Zoom (⌘+ ⌘− ⌘0, pinch) | None |
| "Keep" | No shortcut |

### Global (Carbon hotkeys, `ShortcutModels.swift:35-66`)

Defaults: ⇧⌘V Open Hub, ⇧⌘S Capture Screenshot. Window, full screen, previous area, edit last, pause and
settings are unbound by default. Neither default is shown next to its status-menu item.

## Names in use for the same concept

| Concept | Names found |
|---|---|
| The shelf | "Hub" (menu "Open Hub"), "Edison" (shortcut "Open Edison"), "shelf" (empty-state copy), "Shelf" (layout picker) |
| Area capture | "Capture Screenshot" (menu, shortcut), "Drag to capture an area" (overlay) |
| Image items | "Image" (type), "Image / Screenshot" (title), "Clipboard image" (VoiceOver) |
| Pixelate | "Pixelate" (tool), "Blur Strength" (Settings), "redact" (code), "Drag over anything private" (hint) |
| Annotate | "Annotate Image…" (menu), "Edit Last Screenshot" (status menu), "Screenshot Editor" (window title) |
| Favorite | "Add Favorite"/"Remove Favorite", "Favorites" filter; style guide says "Pin" |
