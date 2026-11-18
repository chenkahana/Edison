RESUME HERE: #42 (E07) re-running CI after a main-actor fix (Xcode 26 Release made a warning an error). Merge order #42→#51 then open PRs for pushed branches e05 e23 e19 e16 e69 e51 e24 e01 e10 (bodies in ~/tmp/codex/edison-impl/pr-*.md). Per merge: run ~/tmp/codex/edison-impl/sync.py in the next worktree (resolves CHANGELOG), push, wait CI, merge. ChenK14 has no admin: approve in Chrome. Run ~/tmp/codex/edison-impl/xb.sh <worktree> (local Release build) before pushing.

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

## Next items (branches pushed, PR opens when its turn comes)

- [ ] E05 Unavailable status-menu items disabled — branch craft/e05-disable-unavailable-menu-items
- [ ] E23 ⇧Return on non-text beeps — branch craft/e23-plain-paste-beep
- [ ] E19 + E37 Empty states name what is empty — branch craft/e19-empty-states
- [ ] E16 ⌘Z undoes a Hub delete — branch craft/e16-command-z-undo-delete
- [ ] E69 No-Accessibility paste says "Copied — Press ⌘V" — branch craft/e69-copied-press-command-v
- [ ] E51 Editor verbs Save…, Add to History, Copy (primary), Close — branch craft/e51-editor-verbs
- [ ] E24 Dates for items older than a week — branch craft/e24-dates-for-old-items
- [ ] E01 + E04 (titles) Status menu shows shortcuts, Settings…, Quit Edison — branch craft/e01-status-menu-shortcuts
- [ ] E10 One selection ring — branch craft/e10-one-selection-ring
- [ ] E15 Esc clears search first — PR https://github.com/chenkahana/Edison/pull/49
- [ ] E08 Hub key from first frame — PR https://github.com/chenkahana/Edison/pull/47
- [ ] E09 Hub on pointer display — PR https://github.com/chenkahana/Edison/pull/48
- [ ] E36 Delete Collection confirms — PR https://github.com/chenkahana/Edison/pull/50
- [ ] E62 Restore All Defaults confirms (and says when it trims history) — PR https://github.com/chenkahana/Edison/pull/51

## Skipped (not gated, but not done)

- E14 / P07 double-click: backlog says only if F2 reproduces; needs the live take.
- E06 / P19 paused glyph: menu-bar icon artwork is Chen's.
- E67 / P20 retention menu: a one-click picker can trim hundreds of items via `trimHistoryToSettingsLimit`; needs a confirm design first. Age retention is new scope.
- P16 copy pass (E64, E61, E40, E42 rename): marked Chen (glossary).

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
