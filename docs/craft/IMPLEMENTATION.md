RESUME HERE: S1 PRs #42 #43 #44 #45 #46 open, CI queued (macOS runners); merge each when green (merge origin/main into the next to resolve CHANGELOG); next P02 (E08).

# Implementation tracker

Chen approved 2026-11-18: build the backlog items that don't need his decision. Branch `craft/<id>-<slug>`, worktree
`~/.worktrees/Edison/craft-<id>-<slug>` (the worktree hook allows only two path levels). Changes go under
`## 2.2 — unreleased` in CHANGELOG.md.

## S1s

- [ ] E07 + E44 Esc, hotkey-close and capture-cancel give focus back (minimal `NSApp.hide` fix, not the panel redesign) — PR https://github.com/chenkahana/Edison/pull/42
- [ ] E68 Screen Recording "Open System Settings" works after the first prompt — PR https://github.com/chenkahana/Edison/pull/43
- [ ] E73 Drag-out offers the same representations as paste (lift not included) — PR https://github.com/chenkahana/Edison/pull/44
- [ ] E59 Clear History confirms and states the scope (still deletes collections; keeping them is Chen's call) — PR https://github.com/chenkahana/Edison/pull/45
- [ ] E83 Paste-back sends ⌘V through the current keyboard layout — PR https://github.com/chenkahana/Edison/pull/46

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
