# R2 Findings

Every surface through the 14 rubric checks (`PLAN.md` §2). Base `origin/main` `f59abfe`.

**Format.** `ID` · finding · rubric check (1–14) · evidence · Severity (S1 broken/inaccessible, S2 visibly unpolished
in a main flow, S3 noticed by a careful user, S4 nit) · Reach (E every session, D daily, O occasional, R rare) ·
Effort (S, M, L) · Score · constraint touched (PF paste fidelity, KB keyboard-first, MB menu-bar-only, LO local-only,
or none) · status.

**Score** = severity × reach ÷ effort with S1=4, S2=3, S3=2, S4=1; E=4, D=3, O=2, R=1; S=1, M=2, L=4 (same numbers as
the Jimmy and Boaz passes).

**Status.** `code` = confirmed by reading the code path end to end; `verify live` = the code strongly implies it but a
recording must confirm before the PR (R0 scripts F1–F10, D1–D7, T1–T5 name the take). No finding here was observed
in the running app in this pass (see R0 for why). "needs Chen" = the fix would change a product constraint or a
default Chen chose.

## R2.1 Menu bar item (S1)

| ID | Finding | Chk | Evidence | Sev | R | Eff | Score | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|
| E01 | Status menu shows no key equivalents for the global hotkeys: "Open Hub" doesn't show ⇧⌘V, "Capture Screenshot" doesn't show ⇧⌘S, and user-assigned capture shortcuts never appear. The menu is the only place a menu-bar app can teach its keys. | 4 | `StatusBarController.swift:58-64` (all `keyEquivalent: ""`) | S3 | D | S | 6 | KB (helps) | code |
| E02 | Menu-bar icon is a raster bulb with a letter "E" (64/128/256 px PNGs) scaled to 18 pt. On Chen's 1× displays the "E" turns to mush; a template icon should be a vector (PDF/SVG) drawn for 16–18 pt with stroke weights that match SF Symbols. | 8, 12 | `Assets.xcassets/menubarIcon.imageset/Contents.json`, `StatusBarController.swift:50-53`; 18 px downscale at `~/tmp/codex/edison-craft/img/menubar-18px-x4.png` | S3 | E | S | 8 | none | code (downscale simulated); verify live on 1× and 2× |
| E03 | Clicking the status item always opens the menu. The style guide's state map has "menu bar click → shelf"; Paste/Maccy open the history on click and keep the menu on right-click or ⌥-click. | 1, 12 | `StatusBarController.swift:76` (`statusItem.menu = menu`); `docs/ui-style-guide.md` state map | S3 | D | S | 6 | MB | code · needs Chen (click behavior) |
| E04 | Menu titles break Mac conventions: "Settings" has no ellipsis and only works with ⌘, while the menu is open; "Quit" should be "Quit Edison"; "Capture Screenshot" is an area capture (the overlay says "Drag to capture an area"), so "Capture Area" is the clearer name. | 11 | `StatusBarController.swift:60,69,73` | S4 | D | S | 3 | none | code |
| E05 | "Edit Last Screenshot" and "Capture Previous Area" fail silently from the menu when there is nothing to edit or no previous area: the error goes to `captureError`, which only renders inside the Hub banner. The items should be disabled (`validateMenuItem`) when unavailable. | 10 | `AppState.swift:564-568`, `CaptureEngine.swift:50-55`, `HubView.swift:224-241` | S2 | O | S | 6 | none | code |
| E06 | Paused state only dims the icon (`appearsDisabled`), which reads as "Edison is broken" rather than "paused"; no distinct glyph (for example a pause badge) and no state while a capture is in progress or a permission is missing. | 10, 12 | `StatusBarController.swift:40-46` | S4 | O | S | 2 | none | code |

## R2.2 Hub shelf (S2)

| ID | Finding | Chk | Evidence | Sev | R | Eff | Score | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|
| E07 | **Esc doesn't give focus back.** Opening the Hub activates Edison (`NSApp.activate(ignoringOtherApps:)`); Esc, the hotkey again and the close path only slide the window out and never re-activate the source app or hide Edison. Only paste calls `NSApp.hide`. Expected result: after Esc, keystrokes go nowhere until the user clicks the app they were in. | 1 | `WindowRouter.swift:66-70,138-149`, `AppState.swift:443-447,650-663`; contrast `WindowRouter.swift:164-167` | S1 | E | S | 16 | KB | verify live (F1) |
| E08 | **Type-ahead lost while the shelf slides in.** The window is ordered front at once but only made key in the animation's completion handler, 200 ms later; keys typed in that window (⇧⌘V then "inv…") don't reach search. | 1, 13 | `WindowRouter.swift:243-252` | S2 | E | S | 12 | KB | verify live (F1, T1) |
| E09 | **Shelf can open on the wrong display.** Its frame is computed from `window.screen ?? NSScreen.main`, i.e. the display it was last on, not the display with the pointer or the key window. Chen runs two displays. | 1, 3 | `HubTheme.swift:200-213`, `WindowRouter.swift:234,256` | S2 | D | S | 9 | none | verify live (D1) |
| E10 | **Selection colour depends on the item.** The selected card's 2 pt stroke is the item's type accent (green text, blue link, purple code, red image, grey file, or the swatch itself for colours), so selection looks different on every card and can vanish on a white or grey item. The guide says not to rely on colour alone. Use one selection treatment (system accent ring + fill). | 2, 9 | `HubShelfView.swift:128-138`, `HubTheme.swift:39-50`; `docs/ui-style-guide.md` "Do not rely on color alone" | S2 | E | S | 12 | none | code |
| E11 | **Motion has three voices and snaps where it matters.** Window slide is AppKit `easeInEaseOut` 0.20/0.18 s, scroll-to-selection is SwiftUI `easeInOut` 0.16 s, toasts use an untokenised `spring(0.3, 0.8)`, and `HubTheme.Anim` tokens are used once. Selection, filter/search result changes and card insert/delete have no animation. | 2 | `WindowRouter.swift:247-248,266-267`, `HubView.swift:218-220,238-239,485`, `HubTheme.swift:26-32`, `HubShelfView.swift:149` | S3 | E | M | 4 | none | code; verify live (F1, F3) |
| E12 | **Reduce Motion is ignored.** The shelf still slides and toasts still move; 0 uses of `accessibilityReduceMotion` / `NSWorkspace.accessibilityDisplayShouldReduceMotion`. | 2, 14 | R0.2 sweep; `WindowRouter.swift:233-273` | S3 | E | S | 8 | none | code |
| E13 | **Hub steals activation from the app being pasted into.** The Hub is a titled `NSWindow`, not the non-activating `NSPanel` the style guide specifies, so the source app's selection greys out while the Hub is up and every paste needs a re-activation dance with a 120 ms wait and 40 ms polls. | 3 | `AppDelegate.swift:83-93`, `HubTheme.swift:179-199`, `PasteBackCoordinator.swift:43-45,151-176`; `docs/ui-style-guide.md` "Window setup" | S2 | E | L | 3 | PF, KB (paste-back path) | code · needs Chen (architecture of paste-back) |
| E14 | **Double-click to paste may not register reliably.** The single-tap gesture is attached before the double-tap gesture on the same card (in both shelf and list), the order SwiftUI resolves in favour of the single tap. | 4, 5 | `HubShelfView.swift:153-158`, `HubListView.swift:147-152` | S2 | D | S | 9 | none | verify live (F2) |
| E15 | **Esc always closes, even mid-search.** macOS convention (and the style guide's state map) is Esc clears the query first, then closes. | 4 | `HubSupportViews.swift:445-447`; guide "Searching → ShelfVisible: Escape" | S3 | D | S | 6 | KB | code |
| E16 | **Undo delete is mouse-only and short-lived.** ⌘⌫ deletes, but ⌘Z does nothing in the Hub; the only undo is a 4 s toast button, which is gone if the Hub closes. | 4, 10 | `HubSupportViews.swift:371-451` (no ⌘Z), `ClipboardCoordinator.swift:237-243` | S2 | O | S | 6 | KB | code |
| E17 | **Tertiary text fails contrast.** `textTertiary` (black 38 % light, white 45 % dark) carries the size/line-count metadata and separators. Over a white backdrop that is about 2.7:1 (light) and 4.4:1 over the dark glass base, before wallpaper bleeds through. | 9 | `HubTheme.swift:63-66`, `HubShelfView.swift:453-459`; contrast computed from the token values | S2 | E | S | 12 | none | code (computed); verify live on bright wallpaper |
| E18 | **Card previews can misstate the content.** Any text containing "- ", "`", "**", "# " and similar is rendered as Markdown, which joins single line breaks and hides syntax characters, so the card doesn't show what will paste. JSON is reformatted with sorted keys. | 8, 10 | `HubView.swift:524-589`, `HubSupportViews.swift:94-114` | S3 | D | S | 6 | PF (display only, but trust) | code |
| E19 | **Favorites tab empty says "No History Yet".** `isFilteringActive` ignores the Favorites filter, so an empty Favorites view tells the user to start copying. | 10, 11 | `HubView.swift:59-63,243-262` | S2 | O | S | 6 | none | code |
| E20 | **Header is crowded and fixed-width.** Search, All/Favorites, a 6-segment type picker, a layout picker, a collection menu and a permanent "New collection" field + Create button share one 278 pt shelf; when it doesn't fit, `ViewThatFits` drops to two rows and takes card height. | 8 | `HubHeaderView.swift:12-68`, `HubTheme.swift:21` | S3 | E | M | 4 | none | verify live (F1 screenshot) |
| E21 | **Geometry isn't concentric and type isn't the ramp.** Card radius 18 sits 20 pt inside a 28 pt window (concentric is 8); image previews use radius 10 inside a 12 pt card inset. Card text is 14 pt medium, link host 17 pt bold and metadata 12 pt semibold against the guide's 12/10 pt card ramp; 35 fixed `.system(size:)` calls in all. | 8 | `HubTheme.swift:5-10`, `HubView.swift:204`, `HubShelfView.swift:190,209-213,267,274,450-457`; guide "Typography" | S3 | E | M | 4 | none | code |
| E22 | **Rendering work on every frame.** Each card's initializer parses the full text as JSON and Markdown; text cards run `text.count` and a full `split("\n")`; each thumbnail does a file-system stat per render; every card draws two large blurred shadows over a behind-window material. Large items or 250+ histories are likely to hitch. | 13 | `HubSupportViews.swift:87-92`, `HubShelfView.swift:147-148,391-401,475-478` | S2 | O | M | 3 | none | verify live (T2) |
| E23 | **⇧Return on a non-text item does nothing, silently.** | 4, 10 | `HubView.swift:452-460` | S3 | O | S | 4 | PF | code |
| E24 | **Timestamps never become dates.** "now", "5m", "2h", "45d" hand-rolled; old items should read as a date, and `FormatStyle` should do it. | 11 | `HubView.swift:597-613` | S4 | E | S | 4 | none | code |
| E25 | **Layout and filter reset on relaunch.** Shelf/List/Grid and All/Favorites are `@State`, not stored. | 12 | `HubView.swift:33-34` | S4 | D | S | 3 | none | code |
| E26 | **Possible empty-state flash on the first open after launch.** History loads asynchronously and the empty state has no loading variant. | 10 | `AppState.swift:216-224`, `HubView.swift:197-199` | S3 | R | S | 2 | none | verify live (F1 first-after-login) |

## R2.3 Detail pane and preview (S3)

There is no in-Hub detail pane; Space opens the system Quick Look panel on a temporary file.

| ID | Finding | Chk | Evidence | Sev | R | Eff | Score | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|
| E27 | **Quick Look may close the Hub.** The `QLPreviewPanel` becomes key; the Hub's `windowDidResignKey` dismisses it unless a sheet or child window is attached, and the QL panel is neither. If so, Space → preview → Esc lands back in no Hub at all. The standard pattern is `acceptsPreviewPanelControl` on the Hub's responder chain. | 3, 4 | `HubSupportViews.swift:337-347,529-535` | S2 | O | M | 3 | KB | verify live (F3) |
| E28 | **Arrow keys don't move through history while previewing.** The data source has exactly one item, so ←/→ in Quick Look don't advance the selection as they do in Finder. | 4 | `HubSupportViews.swift:537-541` | S3 | O | M | 2 | KB | code |
| E29 | **Previews flatten rich content.** Text is written to a `.txt` file, so RTF/HTML items preview as plain text and links preview as a text file, not the page or a link card. | 10 | `HubView.swift:501-519` | S3 | O | M | 2 | PF (display only) | code |
| E30 | **Quick Look is undiscoverable and rewrites its file every render.** It isn't in the context menu (guide's tertiary group) and has no ⌘Y; `quickLookURL(for:)` runs inside `body`, rewriting the temp file on each re-render while the panel is open. | 4, 13 | `HubView.swift:80-87`, `HubSupportViews.swift:210-253`; guide "Context menus" | S4 | O | S | 2 | none | code |

## R2.4 Search (S4)

| ID | Finding | Chk | Evidence | Sev | R | Eff | Score | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|
| E31 | **The last search sticks.** Nothing clears `activeQuery`, the type filter or the selected collection when the Hub opens, so after a search-and-paste the next ⇧⌘V shows the old filtered list, and type-to-search appends to the old query. | 1, 4 | `AppState.swift:27` (only assignment), `HubView.swift:147-153` (open resets focus and selection, not the query) | S2 | E | S | 12 | KB | verify live (F3) |
| E32 | **Space can't be typed into search** unless the field was focused with ⌘F: type-to-search drops whitespace and Space opens Quick Look. The engine is built for multi-word queries ("all words must match"). | 4 | `HubSupportViews.swift:427-429,453-461`, `docs/architecture.md` "Hub interaction" | S2 | D | S | 9 | KB | code |
| E33 | **Type-to-search bypasses text input.** Characters typed with ⌥ are dropped, dead-key accents and input methods (CJK composition) can't work because the bridge appends `event.characters` itself; there's no caret in the pill while this happens. | 4, 14 | `HubSupportViews.swift:453-461`, `HubView.swift:491-499` | S3 | O | M | 2 | KB | code |
| E34 | **Search runs several times per render.** `filteredItems` is a computed property; `HubView.items` is read for `selectedItem`, `isEmpty`, `onChange(of: items.map(\.id))` and the `ForEach`, each a full `localizedCaseInsensitiveContains` pass over every item's full text. Cheap at 500 short items, slow with large texts. | 13 | `AppState.swift:58-72`, `HubView.swift:44-57,170,197`, `HistorySearchEngine.swift:100-107`; count `Search Filter` signposts per keystroke | S3 | O | S | 4 | none | verify live (T3) |
| E35 | **Results give no feedback.** No match highlighting (2.0 plan P1 item 5), no result count, results swap without motion, and the `app:`/`type:` tokens are only taught by the placeholder. | 2, 10 | `HubHeaderView.swift:75`, `/Users/chenk/Edison/docs/edison-2.0-plan.md` P1 | S3 | D | M | 3 | none | code |

## R2.5 Collections (S5)

| ID | Finding | Chk | Evidence | Sev | R | Eff | Score | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|
| E36 | **Deleting a collection is one unlabelled click, no confirmation, no undo.** The trash button next to the picker has no `.help` or accessibility label and removes the collection at once. | 10, 11, 14 | `HubHeaderView.swift:175-183`, `AppState.swift:371-377` | S2 | O | S | 6 | none | code |
| E37 | **A new collection opens on the wrong empty state.** Creating one selects it, and an empty collection shows "No Matching Items · Try a different search query, collection, or type filter." It should say the collection is empty and how to add items (right-click → Collections, or drag). | 10, 11 | `AppState.swift:360-369`, `HubView.swift:59-63,243-262` | S2 | O | S | 6 | none | code |
| E38 | **No drag into a collection, no drag in at all.** Nothing in the app accepts drops (0 `onDrop`/`dropDestination`), so cards can't be dragged onto a collection and files/images can't be dropped onto the shelf. | 5 | R0.2 sweep | S3 | O | M | 2 | none | code |
| E39 | **Collections are mouse-only.** No shortcut to assign the selection to a collection or jump between collections (2.0 plan P1 item 4); no rename or reorder; a permanent "New collection" text field sits in the header instead of a "New Collection…" menu item. | 4 | `HubHeaderView.swift:142-191`, `HubSupportViews.swift:232-245` | S3 | O | M | 2 | KB | code |
| E40 | **Small feedback gaps.** Creating a duplicate name silently does nothing; the context submenu draws `circle`/`checkmark.circle.fill` images instead of standard menu check marks. | 10, 11 | `AppState.swift:363`, `HubSupportViews.swift:233-244` | S4 | O | S | 2 | none | code |

## R2.6 Capture overlay (S6)

| ID | Finding | Chk | Evidence | Sev | R | Eff | Score | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|
| E41 | **No crosshair.** The overlay never sets a cursor, so area mode keeps the arrow; there are no pointer coordinates before the drag starts. | 6 | `CaptureEngine.swift:266-520` (no `NSCursor`), `SelectionOverlayView` | S2 | D | S | 9 | none | verify live (F6) |
| E42 | **"Show Magnifier and Dimensions" has no magnifier.** The setting only toggles the size badge; there is no loupe for pixel-accurate edges. Rename now, build the loupe later. | 6, 11 | `SettingsView.swift:218`, `CaptureEngine.swift:72,606-623` | S2 | O | S | 6 | none | code |
| E43 | **Pointer tracking does heavy work per move.** Every mouse move runs `CGWindowListCopyWindowInfo` over all on-screen windows and invalidates every display's overlay, each of which redraws its full-screen snapshot and dim. Likely hitches at 120 Hz and a lagging window highlight on the second display. | 6, 13 | `CaptureEngine.swift:357-362,388-390,439-449,460-484,537-547` | S2 | D | M | 4.5 | none | verify live (T4, D5) |
| E44 | **Esc and capture leave focus on Edison.** `begin` activates Edison; cancel and finish never hand focus back. | 1, 6 | `CaptureEngine.swift:285,508-518` | S2 | D | S | 9 | KB | verify live (F6) |
| E45 | **Capture is silent.** No shutter sound (macOS plays one unless sound effects are off), no flash, no confirmation; with "Open Editor After Capture" off, a capture leaves no trace until the Hub is opened. | 6, 10 | 0 `NSSound`/`AudioServices`; `CaptureCoordinator.swift:118-127` | S3 | D | S | 6 | none | code |
| E46 | **Capture errors are invisible and mislabelled.** Failures set `captureError`, shown only as a banner inside the Hub (usually closed during capture), and the banner always offers a "Screen Recording" button, even for "No previous capture area is available yet." or "The selected window is no longer available." | 10, 11 | `CaptureCoordinator.swift:136-140`, `HubSupportViews.swift:150-191`, `CaptureEngine.swift:54,121` | S2 | O | S | 6 | none | code |
| E47 | **Space mid-drag throws the selection away.** Space toggles area/window and resets the drag; in macOS ⇧⌘4 Space-while-dragging moves the selection, Shift locks an axis, Option resizes from the centre. Muscle-memory clash. | 6 | `CaptureEngine.swift:397-404` | S3 | D | M | 3 | none | code |
| E48 | **The frozen frame isn't what gets captured.** The overlay shows a `CGDisplayCreateImage` snapshot, but the result is a fresh ScreenCaptureKit capture after the overlay closes, so menus, tooltips or video frames visible during selection can differ in the result. | 6 | `CaptureEngine.swift:500-506`, `CaptureEngine.swift:89-115,165-194` | S3 | O | M | 2 | none | verify live (F6) |
| E49 | **Overlay chrome is loud and off-system.** Instruction text is drawn at the top of every display (13/11 pt white over a 28 % dim, no shadow; low contrast on bright content); the window highlight is an orange 3 pt stroke with 12 pt corners rather than the system's translucent fill. | 6, 9 | `CaptureEngine.swift:547-604` | S4 | D | S | 3 | none | verify live (F6) |
| E50 | **A selection that crosses displays is cut at the edge.** The area is captured on the display containing the rectangle's midpoint. | 6 | `CaptureEngine.swift:384,89-115` | S3 | R | M | 1 | none | verify live (D4) |

## R2.7 Screenshot editor (S7)

| ID | Finding | Chk | Evidence | Sev | R | Eff | Score | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|
| E51 | **"Done" can discard.** The prominent orange button is labelled Done and bound to Esc, but with unsaved changes it raises "Discard Changes?"; "Keep" (add to history without copying) sits next to Save and Copy. Four verbs for one decision. | 7, 11 | `EditorWindowView.swift:95-101,146-172`, `AppState.swift:500-511` | S2 | D | S | 9 | none | code |
| E52 | **No menu bar while editing.** Edison is `.accessory`, so the editor and Settings get no File/Edit/Window menus: ⌘W and ⌘M probably do nothing, and editor shortcuts are only discoverable through tooltips. Switching to `.regular` while a window is open shows a Dock icon. | 4, 12 | `AppDelegate.swift:18`, `EditorWindowView.swift:129-170` | S2 | D | M | 4.5 | MB | verify live (F7: ⌘W) · needs Chen |
| E53 | **Cursors don't follow the tool.** Arrow for Select and crosshair for everything else; no resize cursors over handles, no I-beam for Text, no move cursor over a selected annotation. | 7 | `EditorWindowView.swift:330-336,375-381` | S3 | D | S | 6 | none | code |
| E54 | **No haptics on snap.** Shift-snapping lines to 45°, squares/circles and square crops give no trackpad feedback (`NSHapticFeedbackManager` unused). | 7 | `EditorWindowView.swift:445-452`, R0.2 sweep | S3 | D | S | 6 | none | code |
| E55 | **Save blocks the app.** ⌘S runs an app-modal `NSSavePanel.runModal()` instead of a sheet on the editor, then renders and writes the PNG on the main thread. | 7, 13 | `AppState.swift:582-600` | S3 | D | S | 6 | none | code |
| E56 | **Copy renders on the main thread.** `copyActiveScreenshot` renders the full-resolution PNG and builds the history thumbnail synchronously; on a Retina full-screen capture this is a visible stall before the editor closes. | 7, 13 | `AppState.swift:577-580`, `CaptureCoordinator.swift:155-170`, `ScreenshotDocument.swift:621` | S3 | D | M | 3 | none | verify live (T4) |
| E57 | **No zoom.** The canvas always fits the window; there is no ⌘+/⌘−/⌘0 or pinch, so precise annotation on a large capture means a small target. | 7 | `EditorWindowView.swift:296-341` (fit only) | S2 | D | L | 2.25 | none | code |
| E58 | **Each arrow-key nudge is its own undo step.** Ten nudges need ten ⌘Z. | 7 | `ScreenshotDocument.swift:546-552`, `EditorWindowView.swift:697-709` | S4 | O | S | 2 | none | code |

## R2.8 Settings (S8)

| ID | Finding | Chk | Evidence | Sev | R | Eff | Score | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|
| E59 | **Clear History is one click with no confirmation and no undo**, and it also deletes every collection. The 2.0 plan asks for "clear scope and undo where feasible". | 10, 11 | `SettingsView.swift:302-305`, `AppState.swift:449-453`; `/Users/chenk/Edison/docs/edison-2.0-plan.md` P1 Privacy item 3 | S1 | R | S | 4 | LO | code |
| E60 | **Default hotkeys collide with standard app commands.** Carbon-registered ⇧⌘S takes "Save As…/Duplicate" away from every app while Edison runs; ⇧⌘V takes "Paste and Match Style" from Mail, Notes, Pages and others. | 12 | `ShortcutModels.swift:35-43,53-56` | S2 | D | S | 9 | KB | code · needs Chen (defaults) |
| E61 | **A toggle that does nothing.** "Start Hidden When Launched at Login" is stored but never read. | 10, 11 | `AppSettings.swift:41`, `SettingsView.swift:165-168` (only uses) | S3 | O | S | 4 | none | code |
| E62 | **Restore Defaults has no confirmation.** "Restore All Defaults" in the sidebar resets settings and shortcuts at once; each pane has its own "Restore Defaults" too. | 10 | `SettingsView.swift:85-94,132-136` | S2 | R | S | 3 | none | code |
| E63 | **Not shaped like a Mac Settings window.** A fixed 960×720 split view with a search field and glass detail background for seven short panes; reopens on General every time; pane titles don't match their toolbar-style names ("Storage & Privacy", "Permissions & Support"). | 12 | `SettingsView.swift:52-106` | S3 | O | M | 2 | none | verify live (F8) |
| E64 | **Copy drift.** "Blur Strength" for a tool now called Pixelate; "Calculating..." with three dots; "Fix Access" vs "Open Settings" on the same card; "Pause / Resume History" and "Open Edison" for actions the menu calls "Pause Clipboard History" and "Open Hub"; About shows version 2.0 for the 2.1 release (`MARKETING_VERSION = 2.0`). | 11 | `SettingsView.swift:60,276,423`, `ShortcutModels.swift:19,25`, `Edison.xcodeproj/project.pbxproj` | S3 | O | S | 4 | none | code |
| E65 | **Permission status goes stale.** Screen Recording status refreshes only on appear or "Refresh Status"; after granting in System Settings the card keeps saying "Needs Attention". | 10 | `SettingsView.swift:107-111,316-338` | S3 | O | S | 4 | none | verify live (F9) |
| E66 | **Storage size is recomputed on the main thread after every settings change** by walking the whole storage folder. | 13 | `SettingsView.swift:114-120,429-447` | S3 | O | S | 4 | none | verify live (F8) |
| E67 | **History limit is a 25-step stepper from 25 to 1000** (39 clicks end to end) and there is no age-based retention (2.0 plan P1). | 8, 12 | `SettingsView.swift:286-294` | S4 | R | S | 1 | LO | code |
