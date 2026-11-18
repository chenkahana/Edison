RESUME HERE: #42 (E07) merged. Every other item is in batch PR #68 (craft/batch-1, one commit per item plus 'Clear History keeps collections' and the 2.2 changelog); CI running. When green: squash-merge #68 (gh merge worked without admin for #42; Chrome approval if blocked). #43–#67 closed, linking #68.

# Implementation tracker

Chen approved 2026-11-18: build the backlog items that don't need his decision. Branch `craft/<id>-<slug>`, worktree
`~/.worktrees/Edison/craft-<id>-<slug>` (the worktree hook allows only two path levels). Changes go under
`## 2.2 — unreleased` in CHANGELOG.md.

## S1s

- [x] E07 + E44 Esc, hotkey-close and capture-cancel give focus back (minimal `NSApp.hide` fix, not the panel redesign) — PR https://github.com/chenkahana/Edison/pull/42 (merged 88ba099)
- [ ] E68 Screen Recording "Open System Settings" works after the first prompt — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #43)
- [ ] E73 Drag-out offers the same representations as paste (lift not included) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #44)
- [ ] E59 Clear History confirms and states the scope (collections now kept, emptied, per orchestrator; Chen can change) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #45)
- [ ] E83 Paste-back sends ⌘V through the current keyboard layout — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #46)

## Backlog order, not gated

- [ ] E08 Hub key from first frame (P02) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #47)
- [ ] E09 Hub on pointer display (P03) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #48)
- [ ] E15 Esc clears search first (P05; ⌃U not included) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #49)
- [ ] E36 Delete Collection confirms (P10) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #50)
- [ ] E62 Restore All Defaults confirms, says when it trims history (P10) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #51)
- [ ] E05 Unavailable status-menu items disabled (P12) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #52)
- [ ] E23 ⇧Return on non-text beeps (P12) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #53)
- [ ] E19 + E37 Empty states name what is empty (P13) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #54)
- [ ] E16 ⌘Z undoes a Hub delete (P14) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #55)
- [ ] E69 No-Accessibility paste: "Copied — Press ⌘V" (P15) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #56)
- [ ] E51 Editor verbs (P17) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #57)
- [ ] E24 Dates for items older than a week (P18) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #58)
- [ ] E01 + E04 titles: status menu shows shortcuts, Settings…, Quit Edison (P21) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #59)
- [ ] E75 Export names and file copy (P26) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #61)
- [ ] E55 Editor Save as sheet, off-main write (P27) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #62)
- [ ] E30 Quick Look file written once (P29) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #67)
- [ ] E10 One selection ring (P34) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #60)
- [ ] E17 Card metadata contrast (P35) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #63)
- [ ] E41 Crosshair cursor (P40) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #65)
- [ ] E45 Capture sound (P41) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #64)
- [ ] E79 Editor swatch names (P54) — batch PR https://github.com/chenkahana/Edison/pull/68 (write-up: #66)
- [ ] 2.2 changelog entries — in batch PR https://github.com/chenkahana/Edison/pull/68

## Skipped (not gated, but not done)

- E14 / P07 double-click: backlog says only if F2 reproduces; needs the live take.
- E06 / P19 paused glyph: menu-bar icon artwork is Chen's.
- E67 / P20 retention menu: a one-click picker can trim hundreds of items via `trimHistoryToSettingsLimit`; needs a confirm design first. Age retention is new scope.
- P16 copy pass (E64, E61, E40, E42 rename): marked Chen (glossary).
- W8 speed (E18, E22, E34, E43, E56, E66): backlog says R0 T1–T5 trace numbers first.
- P08 (E27/E28), P23–P25, P28, P37–P39, P42, P44, P45, P47, P52, P53, P55, P59: M/L size; not started this session.
- E74 share anchor, E54 haptics, E53 editor cursors, E58 nudge undo, E76, E49, E50, E46 HUD, E65/E71/E72: not started this session.

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
