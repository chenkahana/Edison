RESUME HERE (2026-11-24): batch-5 (#72: E66, E34) merged. PR #73 (craft/batch-6, E18) CI green, merging. PR #74 (craft/batch-7, E43 partial) open, CI running. Verification is build+launch+window-scoped-screenshot (`screencapture -x -o -l <windowID>`, never full-screen) gated on `pgrep -x CptHost` + `ioreg` HIDIdleTime<300s, re-checked before every step. F1's old Hub-didn't-open note was a test mistake, not a bug: the 2.2 default is ⌃⌥⌘V, not the legacy ⇧⌘V. Three attempts to detect the Hub's own window via CGWindowList (by owner name twice, by owner PID with `.optionOnScreenOnly`+`.optionAll` once) found nothing Hub-sized — logged as owed to Chen, not spending more turns on it. E43's remaining piece (per-display redraw) and E56 (copy renders on main thread) are deliberately not attempted blind: both touch either multi-display rendering or the exact ordering between render/persist/clipboard-suppress that paste fidelity depends on, and need a live before/after check, not just reasoning. Same reasoning applies to every M/L design-token item (P08/P23-P25/P28/P37-P39/P42/P44/P45/P47/P52/P53/P55/P59) — all of them add or change on-screen behavior the backlog itself flags as needing a live check (F-numbers/VoiceOver/FKA takes), and the Hub-window-detection gap means I can't currently confirm those reliably. P16 copy pass stays waiting: Chen (glossary). E14 still needs a live take.

# Implementation tracker

Chen approved 2026-11-18: build the backlog items that don't need his decision. Branch `craft/<id>-<slug>`, worktree
`~/.worktrees/Edison/craft-<id>-<slug>` (the worktree hook allows only two path levels). Changes go under
`## 2.2 — unreleased` in CHANGELOG.md.

## S1s

- [x] E07 + E44 Esc, hotkey-close and capture-cancel give focus back (minimal `NSApp.hide` fix, not the panel redesign) — PR https://github.com/chenkahana/Edison/pull/42 (merged 88ba099)
- [x] E68 Screen Recording "Open System Settings" works after the first prompt — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #43)
- [x] E73 Drag-out offers the same representations as paste (lift not included) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #44)
- [x] E59 Clear History confirms and states the scope (collections now kept, emptied, per orchestrator; Chen can change) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #45)
- [x] E83 Paste-back sends ⌘V through the current keyboard layout — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #46)

## Backlog order, not gated

- [x] E08 Hub key from first frame (P02) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #47)
- [x] E09 Hub on pointer display (P03) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #48)
- [x] E15 Esc clears search first (P05; ⌃U not included) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #49)
- [x] E36 Delete Collection confirms (P10) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #50)
- [x] E62 Restore All Defaults confirms, says when it trims history (P10) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #51)
- [x] E05 Unavailable status-menu items disabled (P12) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #52)
- [x] E23 ⇧Return on non-text beeps (P12) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #53)
- [x] E19 + E37 Empty states name what is empty (P13) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #54)
- [x] E16 ⌘Z undoes a Hub delete (P14) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #55)
- [x] E69 No-Accessibility paste: "Copied — Press ⌘V" (P15) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #56)
- [x] E51 Editor verbs (P17) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #57)
- [x] E24 Dates for items older than a week (P18) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #58)
- [x] E01 + E04 titles: status menu shows shortcuts, Settings…, Quit Edison (P21) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #59)
- [x] E75 Export names and file copy (P26) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #61)
- [x] E55 Editor Save as sheet, off-main write (P27) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #62)
- [x] E30 Quick Look file written once (P29) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #67)
- [x] E10 One selection ring (P34) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #60)
- [x] E17 Card metadata contrast (P35) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #63)
- [x] E41 Crosshair cursor (P40) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #65)
- [x] E45 Capture sound (P41) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #64)
- [x] E79 Editor swatch names (P54) — batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c) (write-up: #66)
- [x] 2.2 changelog entries — in batch PR https://github.com/chenkahana/Edison/pull/68 (merged b631d9c)
- [x] E58 Editor nudges coalesce into one undo (P30, part) — batch PR https://github.com/chenkahana/Edison/pull/70 (merged)
- [x] E54 Trackpad haptic on Shift-snap (P57) — batch PR https://github.com/chenkahana/Edison/pull/70 (merged)
- [x] E53 Editor cursors follow the tool (P56) — batch PR https://github.com/chenkahana/Edison/pull/70 (merged)
- [x] E74 Share anchors at the card, sends full item (P26, part) — batch PR https://github.com/chenkahana/Edison/pull/70 (merged)
- [x] E76 Editor drag-out renders lazily (P30, part) — batch PR https://github.com/chenkahana/Edison/pull/71 (merged)
- [x] E50 Area selection stays on its starting display (P46) — batch PR https://github.com/chenkahana/Edison/pull/71 (merged)
- [x] E49 Overlay: system-style window highlight, legible instructions (P43, part) — batch PR https://github.com/chenkahana/Edison/pull/71 (merged)
- [x] E46 + E65 + E71 + E72 Capture/background errors in a floating non-modal HUD; Screen Recording status auto-refreshes; Quit & Reopen after a mid-session grant (P11/P12, part) — one commit (shared mechanism) — batch PR https://github.com/chenkahana/Edison/pull/71 (merged)
- [x] E67 History Limit + new age-based Keep History as menus with a confirm step (P20) — **decision (mine, conservative):** any change that would delete items — the menu picks, or Restore Defaults on the Privacy pane — asks first and states the count; favorites are exempt from age-based removal — batch PR https://github.com/chenkahana/Edison/pull/71 (merged)
- [x] E66 Storage Usage computed off the main thread (P51, part) — batch PR https://github.com/chenkahana/Edison/pull/72 (merged)
- [x] E34 Hub `filteredItems` cached and recomputed once per input change instead of once per read (P49) — batch PR https://github.com/chenkahana/Edison/pull/72 (merged)
- [x] E18 Hub cards show text exactly as it will paste; no Markdown/JSON reinterpretation (P48, part) — batch PR https://github.com/chenkahana/Edison/pull/73 (merged)
- [x] E43 Area-selection pointer tracking no longer scans every on-screen window per move (the result was discarded in area mode) — batch PR https://github.com/chenkahana/Edison/pull/74 (open, CI running)

## Skipped (not gated, but not done)

- E14 / P07 double-click: backlog says only if F2 reproduces; needs the live take.
- E06 / P19 paused glyph: menu-bar icon artwork is Chen's.
- P16 copy pass (E64, E61, E40, E42 rename): marked Chen (glossary).
- Hub live check (F1 and others needing the Hub visibly open) owed to Chen: after ⌃⌥⌘V, CGWindowList by owner PID (both `.optionOnScreenOnly` and `.optionAll`, so minimized/hidden windows are included) finds only 8 small (1920×30, full-width) layer-0 windows per display pair — menu-bar-height artifacts, not a Hub-sized panel. No Hub panel exists at all, on-screen or off, across three attempts (by owner name, twice; by owner PID with `.optionAll`, once). This looks like the Hub isn't opening in this ad-hoc local build rather than a detection gap, but I can't rule out something specific to this unsigned/ad-hoc test build vs. the real installed app. Needs Chen to confirm ⌃⌥⌘V opens the Hub on his real Edison.
- E43 remainder (per-display full snapshot+dim redraw on every move) and E56 (copy-from-editor renders the final PNG on the main thread, inside the same call that persists to disk and writes the clipboard-suppression handshake): both deliberately not attempted — they touch multi-display rendering or the render/persist/clipboard-suppress ordering paste fidelity depends on, and need a live before/after check I can't currently do reliably (see the Hub live-check note above).
- P08 (E27/E28), P23–P25, P28, P37–P39, P42, P44, P45, P47, P52, P53, P55, P59: M/L size, all add or change on-screen behavior the backlog itself flags as needing a live check (F-numbers/VoiceOver/FKA takes) — not started for the same reason as the Hub live-check gap above.

## Waiting: Chen

- [ ] P09 Hub as a non-activating panel (E13) (waiting: Chen)
- [ ] P32 Default shortcuts (E60) (waiting: Chen)
- [ ] P31 Status item click (E03) (waiting: Chen)
- [ ] P33 Menu bar / Dock while editing (E52) (waiting: Chen)
- [ ] Post-capture thumbnail (waiting: Chen)
- [ ] Names: Hub / Favorite / Pin (waiting: Chen)
- [ ] P04 Fresh Hub on open (E31) (waiting: Chen)
- [ ] P58 First-run window (E70) (waiting: Chen)
- [ ] P36 Menu-bar icon artwork (E02) (waiting: Chen)

## Runtime checks owed

- E07/E44: F1 (Esc, ⇧⌘V close → typing goes to the source app), F6 (Esc during capture).
- E68: F9 with Screen Recording revoked: capture → alert → Open System Settings opens the pane.
- E73: F5 drag rich text into TextEdit (keeps formatting), image into Notes/Finder, file into Finder.
- E59: F8 Clear History… shows counts; Cancel keeps everything.
- E83: paste-back with the Dvorak layout selected pastes (lookup verified offline: Dvorak → key 47).
