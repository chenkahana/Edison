# R5 Backlog

Base `origin/main` `f59abfe`. Scoring as in R2: severity × reach ÷ effort (S1=4…S4=1; E=4, D=3, O=2, R=1; S=1, M=2,
L=4). Ship order: S1 first, then score. Nothing here is implemented; this is the list for Chen to approve.

**Before any PR:** run the R0 Chen session (≈45 min: F1–F10, D1–D7, T1–T5). 34 of 83 findings are `verify live`;
a PR for one of those starts with its recording, and a finding the recording refutes is dropped.

## Summary

**Top 10** (S1 first, then score):

1. E07 Esc doesn't give focus back to the app you were in (S1, every session) → P01
2. E68 Capture-time "Open System Settings" button does nothing after the first prompt (S1) → P11
3. E73 Drag-out offers plain text first for everything, so it doesn't match paste (S1, paste fidelity) → P22
4. E59 Clear History deletes everything, collections included, with no confirmation (S1) → P10
5. E83 Paste-back sends ⌘K instead of ⌘V on Dvorak/Colemak (S1) → P06
6. E08 Keys typed in the first 200 ms after ⇧⌘V are lost → P02
7. E10 Selection colour changes per item and can vanish → P34
8. E17 Card metadata text is about 2.7:1 in Light → P35
9. E31 The last search sticks across opens → P04
10. E09 The Hub opens on the last display, not the pointer's → P03

**Systems in five lines** (R4):

1. Motion: four tokens (`quick`, `standard`, `emphasized`, `gesture`); the window never animates, its content does; Reduce Motion turns movement into fades.
2. Haptics: editor snaps only (`.alignment`), never the keyboard or the Hub list.
3. Layout: derived concentric radii (shelf 28 → card 16 → inner 4), the 4-pt scale with no literals, one accent selection ring, lighter card shadows.
4. Type and copy: text styles only with tabular digits; one English String Catalog, HIG capitalisation, real ellipses, one name per concept.
5. States: one kit (empty variants, inline banner, ⌘Z toast, capture HUD, destructive confirm, live permission flow) and a rule that errors appear where the user is looking.

## R5.1 Ranked findings

| # | ID | Finding | Checks | Sev | Reach | Effort | Score | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|
| 1 | E07 | Esc doesn't give focus back | 1 | S1 | E | S | 16 | KB | verify live (F1) |
| 2 | E68 | The capture-time "Open System Settings" button doesn't open Settings | 10 | S1 | O | S | 8 | none | verify live (F9) |
| 3 | E73 | Dragging a card out doesn't match paste | 5 | S1 | D | M | 6 | PF | verify live (F5) |
| 4 | E59 | Clear History is one click with no confirmation and no undo | 10, 11 | S1 | R | S | 4 | LO | code |
| 5 | E83 | Paste-back types ⌘K on Dvorak | 1, 12 | S1 | R | S | 4 | PF | code; verify live with the Dvorak layout |
| 6 | E08 | Type-ahead lost while the shelf slides in | 1, 13 | S2 | E | S | 12 | KB | verify live (F1, T1) |
| 7 | E10 | Selection colour depends on the item | 2, 9 | S2 | E | S | 12 | none | code |
| 8 | E17 | Tertiary text fails contrast | 9 | S2 | E | S | 12 | none | code (computed); verify live on bright wallpaper |
| 9 | E31 | The last search sticks | 1, 4 | S2 | E | S | 12 | KB | verify live (F3) |
| 10 | E09 | Shelf can open on the wrong display | 1, 3 | S2 | D | S | 9 | none | verify live (D1) |
| 11 | E14 | Double-click to paste may not register reliably | 4, 5 | S2 | D | S | 9 | none | verify live (F2) |
| 12 | E32 | Space can't be typed into search | 4 | S2 | D | S | 9 | KB | code |
| 13 | E41 | No crosshair | 6 | S2 | D | S | 9 | none | verify live (F6) |
| 14 | E44 | Esc and capture leave focus on Edison | 1, 6 | S2 | D | S | 9 | KB | verify live (F6) |
| 15 | E51 | "Done" can discard | 7, 11 | S2 | D | S | 9 | none | code |
| 16 | E60 | Default hotkeys collide with standard app commands | 12 | S2 | D | S | 9 | KB | code · needs Chen (defaults) |
| 17 | E02 | Menu-bar icon is a blurry raster at 18 pt | 8, 12 | S3 | E | S | 8 | none | code (downscale simulated); verify live on 1× and 2× |
| 18 | E12 | Reduce Motion is ignored | 2, 14 | S3 | E | S | 8 | none | code |
| 19 | E81 | Reduce Motion (duplicate of E12; counted once) | 2, 9, 14 | S3 | E | S | 8 | none | code (counted once with E12 in R5) |
| 20 | E05 | Menu items fail silently when unavailable | 10 | S2 | O | S | 6 | none | code |
| 21 | E16 | Undo delete is mouse-only and short-lived | 4, 10 | S2 | O | S | 6 | KB | code |
| 22 | E19 | Favorites tab empty says "No History Yet" | 10, 11 | S2 | O | S | 6 | none | code |
| 23 | E36 | Deleting a collection is one unlabelled click, no confirmation, no undo | 10, 11, 14 | S2 | O | S | 6 | none | code |
| 24 | E37 | A new collection opens on the wrong empty state | 10, 11 | S2 | O | S | 6 | none | code |
| 25 | E42 | "Show Magnifier and Dimensions" has no magnifier | 6, 11 | S2 | O | S | 6 | none | code |
| 26 | E46 | Capture errors are invisible and mislabelled | 10, 11 | S2 | O | S | 6 | none | code |
| 27 | E69 | Paste without Accessibility explains the wrong thing | 10, 11 | S2 | O | S | 6 | PF, KB | code |
| 28 | E77 | VoiceOver can't tell which card is selected or act on it | 14 | S2 | E | M | 6 | KB | verify live (VoiceOver + Accessibility Inspector on the Hub) |
| 29 | E79 | Editor colour swatches all read "Colour" | 11, 14 | S2 | O | S | 6 | none | code |
| 30 | E01 | Status menu hides the global shortcuts | 4 | S3 | D | S | 6 | KB (helps) | code |
| 31 | E03 | Clicking the status item always opens the menu | 1, 12 | S3 | D | S | 6 | MB | code · needs Chen (click behavior) |
| 32 | E15 | Esc always closes, even mid-search | 4 | S3 | D | S | 6 | KB | code |
| 33 | E18 | Card previews can misstate the content | 8, 10 | S3 | D | S | 6 | PF (display only, but trust) | code |
| 34 | E45 | Capture is silent | 6, 10 | S3 | D | S | 6 | none | code |
| 35 | E53 | Cursors don't follow the tool | 7 | S3 | D | S | 6 | none | code |
| 36 | E54 | No haptics on snap | 7 | S3 | D | S | 6 | none | code |
| 37 | E55 | Save blocks the app | 7, 13 | S3 | D | S | 6 | none | code |
| 38 | E43 | Pointer tracking does heavy work per move | 6, 13 | S2 | D | M | 4.5 | none | verify live (T4, D5) |
| 39 | E52 | No menu bar while editing | 4, 12 | S2 | D | M | 4.5 | MB | verify live (F7: ⌘W) · needs Chen |
| 40 | E11 | Motion has three voices and snaps where it matters | 2 | S3 | E | M | 4 | none | code; verify live (F1, F3) |
| 41 | E20 | Header is crowded and fixed-width | 8 | S3 | E | M | 4 | none | verify live (F1 screenshot) |
| 42 | E21 | Geometry isn't concentric and type isn't the ramp | 8 | S3 | E | M | 4 | none | code |
| 43 | E23 | ⇧Return on a non-text item does nothing, silently | 4, 10 | S3 | O | S | 4 | PF | code |
| 44 | E34 | Search runs several times per render | 13 | S3 | O | S | 4 | none | verify live (T3) |
| 45 | E61 | A toggle that does nothing | 10, 11 | S3 | O | S | 4 | none | code |
| 46 | E64 | Copy drift | 11 | S3 | O | S | 4 | none | code |
| 47 | E65 | Permission status goes stale | 10 | S3 | O | S | 4 | none | verify live (F9) |
| 48 | E66 | Storage size is recomputed on the main thread after every settings change | 13 | S3 | O | S | 4 | none | verify live (F8) |
| 49 | E74 | Share sends less than the item and points at nothing | 5, 10 | S3 | O | S | 4 | PF | code |
| 50 | E75 | Export is generic and can stall | 10, 11, 13 | S3 | O | S | 4 | PF | code |
| 51 | E24 | Timestamps never become dates | 11 | S4 | E | S | 4 | none | code |
| 52 | E13 | Hub steals activation from the app being pasted into | 3 | S2 | E | L | 3 | PF, KB (paste-back path) | code · needs Chen (architecture of paste-back) |
| 53 | E22 | Rendering work on every frame | 13 | S2 | O | M | 3 | none | verify live (T2) |
| 54 | E27 | Quick Look may close the Hub | 3, 4 | S2 | O | M | 3 | KB | verify live (F3) |
| 55 | E62 | Restore Defaults has no confirmation | 10 | S2 | R | S | 3 | none | code |
| 56 | E71 | No recovery after granting Screen Recording | 10 | S2 | R | S | 3 | none | verify live (F9) |
| 57 | E78 | Full Keyboard Access can't reach the cards | 4, 14 | S2 | O | M | 3 | KB | verify live (FKA on, Tab through the Hub) |
| 58 | E35 | Results give no feedback | 2, 10 | S3 | D | M | 3 | none | code |
| 59 | E47 | Space mid-drag throws the selection away | 6 | S3 | D | M | 3 | none | code |
| 60 | E56 | Copy renders on the main thread | 7, 13 | S3 | D | M | 3 | none | verify live (T4) |
| 61 | E04 | Menu titles break Mac conventions | 11 | S4 | D | S | 3 | none | code |
| 62 | E25 | Layout and filter reset on relaunch | 12 | S4 | D | S | 3 | none | code |
| 63 | E49 | Overlay chrome is loud and off-system | 6, 9 | S4 | D | S | 3 | none | verify live (F6) |
| 64 | E76 | Editor drag-out renders at drag start | 5, 13 | S4 | D | S | 3 | none | verify live (F7) |
| 65 | E57 | No zoom | 7 | S2 | D | L | 2.25 | none | code |
| 66 | E26 | Possible empty-state flash on the first open after launch | 10 | S3 | R | S | 2 | none | verify live (F1 first-after-login) |
| 67 | E28 | Arrow keys don't move through history while previewing | 4 | S3 | O | M | 2 | KB | code |
| 68 | E29 | Previews flatten rich content | 10 | S3 | O | M | 2 | PF (display only) | code |
| 69 | E33 | Type-to-search bypasses text input | 4, 14 | S3 | O | M | 2 | KB | code |
| 70 | E38 | No drag into a collection, no drag in at all | 5 | S3 | O | M | 2 | none | code |
| 71 | E39 | Collections are mouse-only | 4 | S3 | O | M | 2 | KB | code |
| 72 | E48 | The frozen frame isn't what gets captured | 6 | S3 | O | M | 2 | none | verify live (F6) |
| 73 | E63 | Not shaped like a Mac Settings window | 12 | S3 | O | M | 2 | none | verify live (F8) |
| 74 | E72 | App-modal alerts from a background menu-bar app | 3, 10 | S3 | O | M | 2 | none | verify live (F9) |
| 75 | E80 | No Increase Contrast variants | 9, 14 | S3 | O | M | 2 | none | verify live (Increase Contrast on) |
| 76 | E06 | Paused status icon reads as broken | 10, 12 | S4 | O | S | 2 | none | code |
| 77 | E30 | Quick Look is undiscoverable and rewrites its file every render | 4, 13 | S4 | O | S | 2 | none | code |
| 78 | E40 | Small feedback gaps | 10, 11 | S4 | O | S | 2 | none | code |
| 79 | E58 | Each arrow-key nudge is its own undo step | 7 | S4 | O | S | 2 | none | code |
| 80 | E70 | No first run | 10, 12 | S2 | R | M | 1.5 | MB | code |
| 81 | E50 | A selection that crosses displays is cut at the edge | 6 | S3 | R | M | 1 | none | verify live (D4) |
| 82 | E67 | History limit is a 25-step stepper from 25 to 1000 | 8, 12 | S4 | R | S | 1 | LO | code |
| 83 | E82 | Annotations and the canvas are invisible to VoiceOver | 14 | S3 | R | L | 0.5 | none | code |

## R5.2 Workstreams

Each finding belongs to exactly one workstream. Score sum adds member scores (E81 counts 0: it duplicates E12).

| WS | Name | Scope | Findings | S1s | Count | Score sum | Depends on |
|---|---|---|---|---|---|---|---|
| W0 | Summon, focus and paste-back | Every exit returns focus; key on frame one; pointer display; fresh state on open; layout-safe ⌘V; Quick Look keeps the Hub | E07, E08, E09, E14, E15, E27, E31, E44, E83, E13 | E07, E83 | 10 | 83 | R0 F1–F3, D1. E13 (non-activating panel) needs Chen |
| W1 | Motion system | R4.1 tokens, content-not-window entrance, selection ring motion, insert/delete, Reduce Motion | E11, E12, E81 | – | 3 | 12 | R4.1; after W0 (shares the open path) |
| W2 | Pointer and haptics | Editor cursors and haptic map | E53, E54 | – | 2 | 12 | R4.2 |
| W3 | Geometry, type and colour | Layout tokens, single selection ring, text-style ramp, contrast, header layout, vector status icon | E02, E10, E17, E20, E21 | – | 5 | 40 | R4.3, R4.4 |
| W4 | States and copy | State kit, confirmations, error placement, String Catalog, glossary, FormatStyle, retention control | E04, E05, E06, E16, E19, E23, E24, E26, E36, E37, E40, E42, E46, E51, E59, E61, E62, E64, E65, E67, E68, E69, E71, E72 | E59, E68 | 24 | 107 | R4.5, R4.6 |
| W5 | Mac nativeness | Menus with shortcuts, real search field, drag in/out with paste fidelity, collections by keyboard, sheets, Settings shape | E01, E03, E25, E28, E29, E30, E32, E33, E35, E38, E39, E52, E55, E58, E60, E63, E73, E74, E75, E76 | E73 | 20 | 79.5 | R2; E03, E52, E60 need Chen |
| W6 | Capture and editor | Crosshair, loupe, macOS drag modifiers, feedback HUD + sound, frozen-frame consistency, cross-display clamp, zoom | E41, E45, E47, E48, E49, E50, E57 | – | 7 | 26.25 | R3.4, R3.5 |
| W7 | System integration | First run; later App Intents ("Copy Last Screenshot", "Paste Item N"), Services | E70 | – | 1 | 1.5 | After W4; App Intents are new scope, need Chen |
| W8 | Speed | Per-render parsing, search memoisation, overlay tracking, off-main rendering and I/O | E18, E22, E34, E43, E56, E66 | – | 6 | 24.5 | R0 T1–T5 numbers first |
| W9 | Accessibility | VoiceOver labels/actions/selected, Full Keyboard Access, Increase Contrast, canvas | E77, E78, E79, E80, E82 | – | 5 | 17.5 | W3 (contrast tokens), W1 (Reduce Motion) |

**Order.** W0 first: it holds the top-ranked S1 (E07) and the structural choice (E13) that W1 builds on. Then W4
(three S1s, mostly small), the W5 drag-fidelity slice (E73, S1), W3, W1, W6, W8, W9, W2, W7. W8 can run alongside
once the R0 traces exist.

## R5.3 PR slices

One visible change per PR, in ship order. Each PR: before/after recording of its flow (the R0 take named in
"Proof"), the constraint it touches checked in the running app, `swift build` + `swift test` green. Size: S under a
day, M a few days, L a week or more. **Chen** = needs Chen's yes before work starts.

| PR | Title | Findings | Proof | Constraint | Size | Chen |
|---|---|---|---|---|---|---|
| P01 | Esc, hotkey-close and capture-cancel give focus back to the app you were in | E07, E44 | F1, F6 | KB | S | |
| P02 | The Hub takes keys from its first frame (content fades in; the window no longer slides) | E08 | F1, T1 | KB | S | |
| P03 | The Hub opens on the display with the pointer | E09 | D1 | none | S | |
| P04 | The Hub opens fresh: query, type filter and collection cleared, newest item selected | E31 | F3 | KB | S | Chen (behaviour) |
| P05 | Esc clears the search before it closes the Hub; ⌃U clears search | E15 | F3 | KB | S | |
| P06 | Paste-back sends ⌘V through the current keyboard layout | E83 | Dvorak take | PF | S | |
| P07 | Double-click pastes reliably (only if F2 reproduces) | E14 | F2 | none | S | |
| P08 | Quick Look keeps the Hub open and arrows move through history | E27, E28 | F3 | KB | M | |
| P09 | Spike: the Hub as a non-activating panel | E13 | F1, F2, T1 | PF, KB | L | **Chen** |
| P10 | Clear History, Delete Collection and Restore Defaults ask first and state the scope | E59, E36, E62 | F4, F8 | LO | S | |
| P11 | Screen Recording: the alert opens the right pane, offers Quit & Reopen, and status updates live | E68, E71, E65, E72 | F9 | none | S | |
| P12 | Capture results and errors appear even when the Hub is closed (capture HUD, per-error actions); unavailable menu items are disabled | E46, E05, E45 (feedback), E23 | F6, F10 | none | M | |
| P13 | Empty states for favorites, collections, no results (with Clear Search) and loading | E19, E37, E26 | F4, F1 | none | S | |
| P14 | ⌘Z undoes a delete in the Hub; the undo toast lasts while hovered | E16 | F4 | KB | S | |
| P15 | Without Accessibility: "Copied, press ⌘V" toast, and paste works on its own once access is granted | E69 | F2 | PF, KB | S | |
| P16 | English String Catalog and copy pass (capitalisation, ellipses, glossary, dead "Start Hidden" toggle removed or wired, small feedback gaps) | E64, E61, E40, E42 (rename) | F8, F10 | none | M | Chen (glossary) |
| P17 | Editor verbs: Copy, Save…, Add to History, Close | E51 | F7 | none | S | |
| P18 | Timestamps and counts through `FormatStyle` | E24 | F1 | none | S | |
| P19 | Paused status icon gets its own glyph | E06 | F10 | none | S | |
| P20 | History retention by age, and a menu instead of a 25-step stepper | E67 | F8 | LO | S | |
| P21 | Status menu shows every shortcut, with Mac titles (Settings…, Quit Edison, Capture Area) | E01, E04 | F10 | KB | S | |
| P22 | Drag out offers the same representations as paste (rich text, PNG, file) with a lift | E73 | F5 + fidelity fixtures | PF | M | |
| P23 | Search is a real text field: Space, ⌥-characters and input methods work | E32, E33 | F3 | KB | M | |
| P24 | Search highlights matches and shows a count | E35 | F3 | none | M | |
| P25 | Collections: drag a card onto one, assign by keyboard, "New Collection…" in a menu (frees the header) | E38, E39, E20 | F4 | KB | M | |
| P26 | Share opens at the card with the full item; Export uses real names and copies files without loading them | E74, E75 | F4 | PF | S | |
| P27 | Editor Save is a sheet and writes off the main thread | E55 | F7 | none | S | |
| P28 | Settings sized to content, remembers its pane; layout and filter remembered across launches | E63, E25 | F8 | none | M | |
| P29 | Quick Look in the context menu (⌘Y) with rich previews | E30, E29 | F3 | none | M | |
| P30 | Editor: nudges coalesce into one undo; drag-out renders lazily | E58, E76 | F7 | none | S | |
| P31 | Status item click opens the Hub; menu on right-click | E03 | F10 | MB | S | **Chen** |
| P32 | New default capture shortcut that doesn't take ⇧⌘S from other apps | E60 | F6 | KB | S | **Chen** |
| P33 | Menu bar (File/Edit/Window) while the editor or Settings is open | E52 | F7 | MB | M | **Chen** |
| P34 | One selection ring on every card | E10 | F1 | none | S | |
| P35 | Card metadata meets 4.5:1 | E17 | F1 Light/Dark | none | S | |
| P36 | Vector menu-bar icon | E02 | F10 at 1× and 2× | none | S | **Chen** (artwork) |
| P37 | Layout tokens and concentric radii | E21 (geometry) | F1 | none | M | |
| P38 | Text-style type ramp | E21 (type) | F1, F7 | none | M | |
| P39 | Motion tokens and Reduce Motion | E11, E12, E81 | F1, F3 with Reduce Motion on/off | none | M | |
| P40 | Crosshair cursor with live coordinates | E41 | F6 | none | S | |
| P41 | Capture plays the system shutter sound | E45 (sound) | F6 | none | S | |
| P42 | Area drag uses macOS modifiers (Space moves, Shift locks, Option centres) | E47 | F6 | none | M | |
| P43 | Overlay: system window highlight, no permanent instruction banner | E49 | F6 | none | S | |
| P44 | Magnifier loupe | E42 (feature) | F6 | none | M | |
| P45 | The capture is the frame you selected from | E48 | F6 | none | M | |
| P46 | Area selection stays on its starting display | E50 | D4 | none | S | |
| P47 | Editor zoom (pinch, ⌘+, ⌘−, ⌘0) | E57 | F7 | none | L | |
| P48 | Card previews parse only what they show (cap, cache) and show text as it will paste | E22, E18 | T2 | PF (display) | M | |
| P49 | Search computed once per keystroke | E34 | T3 | none | S | |
| P50 | Overlay pointer tracking at display refresh | E43 | T4, D5 | none | M | |
| P51 | Copy from the editor renders off the main thread; storage size computed in the background | E56, E66 | T4, F8 | none | S | |
| P52 | VoiceOver: one element per card with selected state, source app and actions | E77 | VoiceOver take | KB | M | |
| P53 | Full Keyboard Access reaches the cards | E78 | FKA take | KB | M | |
| P54 | Editor swatches say their colour and selected state | E79 | VoiceOver take | none | S | |
| P55 | Increase Contrast variants | E80 | F1 with Increase Contrast | none | M | |
| P56 | Editor cursors follow the tool and handle | E53 | F7 | none | S | |
| P57 | Trackpad haptics on editor snaps | E54 | F7 (Force Touch trackpad) | none | S | |
| P58 | First run: one small window teaching ⇧⌘V, capture and permissions | E70 | F9 | MB | M | **Chen** |
| P59 | Accessible canvas (annotations as elements) | E82 | VoiceOver take | none | L | later |

Every finding E01–E83 appears in exactly one row above (E21, E42 and E45 are split across two PRs by part).

## Questions only Chen can answer

1. **Non-activating Hub (P09).** Approve a spike to make the Hub an `NSPanel` that never activates Edison? It fixes
   focus, type-ahead and paste latency at the root, but it touches the paste-back path.
2. **Default shortcuts (P32).** Keep ⇧⌘S for capture (it takes Save As/Duplicate from every app) and ⇧⌘V for the Hub
   (takes Paste and Match Style)? If not, which defaults?
3. **Status item click (P31).** Should a click open the Hub, with the menu on right-click?
4. **Menu bar while editing (P33).** OK to show a Dock icon and menu bar while the editor or Settings is open, or keep
   strictly menu-bar-only and live without ⌘W/Edit menus?
5. **After a capture.** Keep "straight to the editor", or move to a macOS-style floating thumbnail with the editor one
   click away (CleanShot/⇧⌘5 idiom)?
6. **Names.** "Hub" everywhere (vs "Edison"/"shelf"), and "Favorite" vs the style guide's "Pin"?
7. **Fresh Hub on open (P04).** Clear the last search every time the Hub opens?
8. **First run (P58).** Is one small welcome window acceptable for a menu-bar-only app?
9. **Menu-bar icon (P36).** Who draws the vector version?
10. **R0 session.** About 45 minutes with the laptop lid open (120 Hz, Retina) to record F1–F10, D1–D7 and T1–T5;
    34 findings wait on it.
