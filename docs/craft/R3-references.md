# R3 References

Mechanics, not looks: how each reference summons, holds focus, moves, takes keys and handles states, and what Edison
should take from it. Sources are marked: **src** read from the app's source code, **bundle** read from the installed
bundle, **known** documented or long-standing public behaviour, **measure** a number to capture in the R0 Chen
session (durations and curves need a 120 Hz recording; nothing here was recorded in this pass).

Installed on Chen's Mac: Raycast 2.12.1 only (`/Applications`). Maccy is open source (read at
`github.com/p0deje/Maccy` `master`, copies in `~/tmp/codex/edison-craft/ref/maccy/`). Paste and CleanShot X are not
installed; their rows are **known** and need a trial install (needs Chen) to measure.

## R3.1 Paste (pasteapp.io)

| Mechanic | Paste | Edison today | Take |
|---|---|---|---|
| Summon | Global ⇧⌘V; full-width shelf slides up from the bottom edge of the screen (**known**); duration and curve **measure** | Same shape and hotkey; 0.20 s `easeInEaseOut` frame slide, key only after the slide (E08) | Keep the shape. Make the shelf key on the first frame and animate content, not the window frame. |
| Display | Opens on the active screen (**known**, **measure** with pointer vs key window split) | Last display used (E09) | Pointer's display. |
| Keyboard | ←/→ move, Return paste, ⇧Return paste as plain text, ⌘1–9 quick paste, Space preview, type or ⌘F to search, ⌘⌫ delete, ⌘C copy, ⇧⌘C Paste Stack (**known**; the style guide's shortcut table is taken from it) | ←/→, Return, ⇧Return, ⌘1–9, Space, type/⌘F, ⌘⌫ (`HubSupportViews.swift:371-451`); no ⌘C, ⌘R, ⌘N, Paste Stack | Close the gap on ⌘C and ⌘Z; leave Paste Stack and rename for later (2.0 plan P2). |
| Esc | Clears the search first, then closes (**known**; matches the style guide's state map) | Always closes (E15) | Two-step Esc. |
| Search state on reopen | Reopens unfiltered at the newest item (**known**, **measure**) | Keeps the old query and filters (E31) | Reset query, type filter and collection on open. |
| Selection | One consistent highlight, moves with the keys (**measure** whether it animates) | Per-type colour stroke, snaps (E10, E11) | One system-accent ring; short `quick` move. |
| Pinboards | Tabs in the header, assign by drag or menu, keyboard switch (**known**) | Picker + permanent name field + trash (E36–E39) | Pinboards as header tabs; "New Collection…" in a menu. |
| Drag | Drag a card out (keeps formats) or onto a pinboard; multi-select drags (**known**) | Plain text first, no drop targets (E73, E38) | Drag offers the same representations as paste. |
| Paste fallback | Without Accessibility, copies and tells you to press ⌘V (**known**) | Alert, retry required (E69) | Copy + one-line inline note. |

## R3.2 Raycast clipboard history

Raycast 2.12.1, `LSUIElement = 1` (**bundle**), running in Chen's session; not driven in this pass.

| Mechanic | Raycast | Edison today | Take |
|---|---|---|---|
| Window | Centred floating window, appears at once with a short fade, no slide (**known**, **measure**) | Bottom shelf, frame slide | Edison's shelf is a different shape on purpose; borrow the instant key-ready appearance. |
| Display | Setting: screen with the pointer or with the active window (**known**) | Last display (E09) | Default to the pointer's display. |
| Focus | Takes focus while open; Esc or paste hides it and the previous app is frontmost again with its selection intact (**known**, **measure** with TextEdit selection) | Esc leaves Edison active (E07) | Every exit path returns focus: hide the app or re-activate the source. |
| Search field | Always focused; typing, Space, ⌥-characters and input methods all work because it's a real text field (**known**) | Bridge view appends characters; Space opens Quick Look (E32, E33) | Keep the search field the first responder and route only navigation keys (arrows, Return, ⌘-keys) to the list. |
| Esc ladder | Clears text, then leaves the sub-view, then closes (**known**) | Always closes (E15) | Same ladder. |
| Actions | ↩ paste to the frontmost app (named in the button), ⌘↩ copy, ⌘K opens an action panel listing every action with its shortcut (**known**) | Context menu only, few shortcuts shown (E01) | One discoverable action list (context menu with every shortcut, or a ⌘K panel). |
| Detail pane | Right-hand preview of the selected item with metadata (source app, size, date) (**known**) | Quick Look only (E27–E29) | A detail pane is optional; metadata belongs in the card's accessibility value at least. |
| Paste fallback | Without Accessibility, copies and shows a toast saying it was copied (**known**) | Alert (E69) | Toast. |
| Haptics | None in clipboard history (**known**) | None | No haptics in the Hub; keep them for the editor. |
