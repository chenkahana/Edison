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
