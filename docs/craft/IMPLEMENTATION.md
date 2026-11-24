RESUME HERE (2026-11-24): batch-5 (#72), batch-6 (#73), batch-7 (#74), batch-8 (#75) all merged. Batch-9 (#76, craft/batch-9) open, CI running: P39 (motion tokens + Reduce Motion) and P37 (geometry, partial — concentric card/row radius) done and render/build/test-verified; P38 (type ramp, 35+ call sites, some tied to existing line-limit math) and P37's image-preview radius (not an explicit backlog target, a judgment call) deliberately left out — reasons in PR #76's body. E56 decided: skip, logged below. P53/E78 and the net-new-feature items (P47/P44/P42/P25/P23) stay deferred per team-lead's final word. F1: root cause found (Chen's saved shortcut binds openHub to legacy ⇧⌘V, not the 2.2 default ⌃⌥⌘V) — owed to Chen to confirm on his real install. Remaining: merge #76 when green, then send the final report (merged PRs, deferred list, what's owed to Chen).

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
- [x] E43 Area-selection pointer tracking no longer scans every on-screen window per move (the result was discarded in area mode) — batch PR https://github.com/chenkahana/Edison/pull/74 (merged a18d8ae)
- [x] E43 (rest) A capture overlay redraws only when its own drawn content changed, not on every mouse pixel moved on every display — batch PR https://github.com/chenkahana/Edison/pull/75 (merged 86b5ed8)
- [x] P45/E48 An area capture is cropped from the exact frame the overlay showed during selection, not a fresh capture taken after it closes — batch PR https://github.com/chenkahana/Edison/pull/75 (merged 86b5ed8)
- [x] P28/E25 Hub layout (Shelf/List/Grid) and All/Favorites persist across relaunches (`@AppStorage`) — batch PR https://github.com/chenkahana/Edison/pull/75 (merged 86b5ed8)
- [x] P24/E35 Search shows a result count and highlights matching text on cards — render-verified — batch PR https://github.com/chenkahana/Edison/pull/75 (merged 86b5ed8)
- [x] P08/E27+E28 Quick Look no longer closes the Hub when it becomes key; ←/→ in Quick Look browse the whole visible history and keep the Hub's selection in sync — batch PR https://github.com/chenkahana/Edison/pull/75 (merged 86b5ed8)
- [x] P55/E80 Increase Contrast variants for the Hub's glass stroke, dividers, card fills — render-verified (standard-contrast path unchanged, confirmed no regression; the increased-contrast path is verified by code/API reasoning only — see below) — batch PR https://github.com/chenkahana/Edison/pull/75 (merged 86b5ed8)
- [x] E14 Double-click to paste resolves reliably (`TapGesture(count: 2).exclusively(before:)` replaces two independently-resolved `onTapGesture` modifiers — the actual root cause was deterministic, in the code, not something that needed a live reproduction) — batch PR https://github.com/chenkahana/Edison/pull/75 (merged 86b5ed8)
- [x] P52/E77 Cards are one VoiceOver element with `.isSelected`, a words-based timestamp + source app value, and Paste/Copy/Favorite/Delete actions — batch PR https://github.com/chenkahana/Edison/pull/75 (merged 86b5ed8)
- [x] P39/E11+E12+E81 Window slide, scroll-to-selection, and the undo toast are named `HubTheme.Anim` tokens and honor Reduce Motion — render/build/test-verified — batch PR https://github.com/chenkahana/Edison/pull/76 (open, CI running)
- [x] P37/E21 (geometry, partial) Card/row corner radius is concentric with the Hub window (8 pt, per the backlog's own `window − inset = 28 − 20 = 8` math) — render-verified — batch PR https://github.com/chenkahana/Edison/pull/76 (open, CI running)

## Skipped (not gated, but not done)

- E06 / P19 paused glyph: menu-bar icon artwork is Chen's.
- P16 copy pass (E64, E61, E40, E42 rename): marked Chen (glossary).
- Hub live check (F1): root cause found. `CGPreflightPostEventAccess()` returns `true` (synthetic keys do arrive), but Chen's saved shortcut preference (`defaults read com.chenkahana.Edison` → `edison.shortcuts.v2`, base64-decoded JSON) binds `openHub` to keyCode 9 with modifiers 768 = ⇧⌘V (the **legacy** shortcut), not the 2.2 code default of ⌃⌥⌘V. All three prior "no Hub window found" attempts used ⌃⌥⌘V — the wrong key for this saved preference — so they prove nothing about whether the Hub opens. Retried with the correct ⇧⌘V: build relaunched, key posted, but Chen became active (idle gate tripped) before the window-detection read completed; test build was quit and Chen's installed Edison restored immediately. Not resumed since it doesn't block anything else — this is purely the informational "does the Hub open on his real install" question, which only he can answer directly.
- P55/E80's increased-contrast path specifically: the implementation checks the live `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast` flag (same pattern already used for Reduce Motion in `CaptureThumbnail.swift`), which can't be exercised from an offscreen render without flipping Chen's real system Increase Contrast setting — a global, outward-facing change I didn't make without asking. The standard-contrast (default) path is confirmed pixel-identical to before.
- P53/E78 (Full Keyboard Access, Tab-focusable cards): deferred, not a live-check gap. Making cards focusable needs real integration with the Hub's existing custom first-responder keyboard host (arrow keys, number-key quick-paste, and all ⌘-shortcuts funnel through one invisible responder today); bolting on `.focusable()` risks conflicting with that system. Needs a design pass.
- P47/E57 (editor zoom, L), P44/E42 (magnifier loupe), P42/E47 (area-drag modifiers: Space/Shift/Option), P25/E38+E39 (drag into a collection — zero existing `onDrop` support anywhere in the app), P23/E32+E33 (real text-field search, IME/composition-sensitive): genuinely new interaction surface, not bug fixes to existing behavior — needs live interaction session. A render diff can't verify any of these — the open question in each is behavioral (does Space move the selection mid-drag, does a drop land, does composition still work), not visual — so they're not attempted blind. Confirmed with team-lead; holding.
- P38/E21 (type ramp): not attempted — needs live interaction session / a dedicated focused pass, not a live-GUI-check gap. 35+ `.system(size:)` call sites across the Hub; some (`HubShelfView.swift`'s `textLineLimit = max(3, Int((sideLength - 84) / 20))`) hard-code a per-line pixel height tied to the current font size, so swapping sizes without re-deriving that math risks silently wrong line counts or clipped text.
- P37/E21's image-preview radius (10 pt inside a 12 pt inset): not attempted, separate from the card/window fix above. The window/card pair had an explicit backlog-computed target (8 pt); this one doesn't — strict concentric math against the new 8 pt card radius would force it to 0 (inset ≥ outer radius), which is a real aesthetic call, not a mechanical fix. Left for explicit guidance or Chen's own eye.
- P59/E82: the backlog's own status for this item is "later" — not this pass, independent of the live-check question.
- E56 (copy-from-editor renders the final PNG on the main thread): **decided — skip.** `CaptureCoordinator.persistAndCopy` itself already keeps a safe order (render → persist → suppress-then-pasteboard-write, all synchronous, no race); the actual blocker is that `ScreenshotSession.renderedPNGData()`/`renderedCGImage()` are `@MainActor`-isolated and read+mutate session state (`pixelatedCache`, lazily memoized during render, built from live annotations/cropRect). Moving just the render off-actor isn't a clean split — it needs a snapshot-and-copy refactor of the render path (copy the inputs, render off-actor from the copy, hop back to commit), which is more than "move a thread" and risks changing the pixelatedCache memoization or introducing a data race if rushed. Per team-lead's rule, logged and not attempted this session.

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
