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

## R3.3 Maccy (source read)

| Mechanic | Maccy (**src**) | Edison today | Take |
|---|---|---|---|
| Panel type | `NSPanel` with `.nonactivatingPanel`, `isFloatingPanel`, level `.statusBar`, `collectionBehavior [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]`, `hidesOnDeactivate = false` (`FloatingPanel.swift:27-46`) | Titled `NSWindow`, `.floating`, activates Edison (E13) | The source app stays active, so paste needs no re-activation and Esc needs no focus return. This is the structural fix for E07, E08 and E13 together. |
| Open | `orderFrontRegardless()` then `makeKey()` in the same turn; `animationBehavior = .none` (`FloatingPanel.swift:38,85-93`) | Key only after a 200 ms slide (E08) | Key on frame one; animate content opacity/offset inside the panel instead of the window frame. |
| Position | User choice: cursor (default), status item, active window, centre, last position; screen chooser falls back to `NSScreen.main` (`PopupPosition.swift`, `NSScreen+ForPopup.swift`) | Last display only (E09) | For a bottom shelf: the pointer's screen, with a setting for "screen with the active window". |
| Close | `resignKey()` closes unless an alert is up; `close()` resets search and selection (`FloatingPanel.swift:209-226`, `Popup.swift:89-91`) | Closes on resign key; never resets query (E31) | Reset state on close. |
| Esc | Closes, whatever the query (`KeyChord.swift:124-125`); ⌃U clears search, ⌃W deletes a word, ⌃H deletes a char (`KeyChord.swift:73-84`) | Closes (E15) | Maccy and Edison share the one-step Esc; Paste and Raycast use the ladder. Take the ladder, plus ⌃U. |
| Hold-to-cycle | Opened with a held modifier, releasing it pastes the selection, like ⌘Tab (`Popup.swift:11`) | No | Worth evaluating for ⇧⌘V-hold-V-release; needs Chen. |
| Paste | Writes the item, then posts ⌘V to the session tap with local keyboard events suppressed during the paste, and maps "V" through the current keyboard layout, including layouts that switch to QWERTY under ⌘ (`Clipboard.swift:123-149`) | Posts virtual key 9 (`kVK_ANSI_V`) to the target pid after a 120 ms wait (`PasteBackCoordinator.swift:139-149`) | Map the key through the layout (new finding E83) and suppress local keys during the paste. |
| Ignored types | Concealed/transient/auto-generated plus user-defined types, apps and regexes (`Clipboard.swift:27,243-262`) | Concealed/transient/auto-generated only | Per-app exclusions are already 2.0 plan P1. |
| Animation | Only a resize animation for height changes (`FloatingPanel.swift:111`) | Window-frame slide | Proof that "no window animation, instant key" reads as fast. |
