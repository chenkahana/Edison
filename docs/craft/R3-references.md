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
