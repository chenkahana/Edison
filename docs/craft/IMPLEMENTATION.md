RESUME HERE (2026-11-24): batch-5 (#72) through batch-10 (#77) merged; batch-11 (#78: P31, P04, P33, P16) merged; batch-12 (#79: P38 full type-ramp consolidation) open, CI pending. Team-lead separately decided several previously-"owed to Chen"/backlog items (P04, P31, P32, P33, P58, P36, post-capture thumbnail, P16) on Chen's behalf, reversible — see each item below. Of those, P32/P58/P36/the post-capture thumbnail turned out to already be fully implemented (verified by reading the code, not re-done); only P31/P04/P33/P16 needed real changes, all in #78. What's left: genuinely deferred (needs a live interaction session — P47, P44, P42, P25, P23, P53/E78, P09), explicitly "later" per the backlog (P59), skipped with a logged reason (E56), or owed to Chen directly (F1's shortcut binding confirmation, the "Waiting: Chen" section below). No worktree has unpushed work; craft-batch-2 through craft-batch-11 are clean, merged, and good cleanup candidates (`git worktree remove`, not `rm -rf`).

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
- [x] P39/E11+E12+E81 Window slide, scroll-to-selection, and the undo toast are named `HubTheme.Anim` tokens and honor Reduce Motion — render/build/test-verified — batch PR https://github.com/chenkahana/Edison/pull/76 (merged 98ceded)
- [x] P37/E21 (geometry, partial) Card/row corner radius is concentric with the Hub window (8 pt, per the backlog's own `window − inset = 28 − 20 = 8` math) — render-verified — batch PR https://github.com/chenkahana/Edison/pull/76 (merged 98ceded)

## Skipped (not gated, but not done)

- E06 / P19 paused glyph: menu-bar icon artwork is Chen's.
- P16 copy pass (E64, E61, E40, E42 rename): marked Chen (glossary).
- Hub live check (F1): root cause found. `CGPreflightPostEventAccess()` returns `true` (synthetic keys do arrive), but Chen's saved shortcut preference (`defaults read com.chenkahana.Edison` → `edison.shortcuts.v2`, base64-decoded JSON) binds `openHub` to keyCode 9 with modifiers 768 = ⇧⌘V (the **legacy** shortcut), not the 2.2 code default of ⌃⌥⌘V. All three prior "no Hub window found" attempts used ⌃⌥⌘V — the wrong key for this saved preference — so they prove nothing about whether the Hub opens. Retried with the correct ⇧⌘V: build relaunched, key posted, but Chen became active (idle gate tripped) before the window-detection read completed; test build was quit and Chen's installed Edison restored immediately. Not resumed since it doesn't block anything else — this is purely the informational "does the Hub open on his real install" question, which only he can answer directly.
- P55/E80's increased-contrast path specifically: the implementation checks the live `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast` flag (same pattern already used for Reduce Motion in `CaptureThumbnail.swift`), which can't be exercised from an offscreen render without flipping Chen's real system Increase Contrast setting — a global, outward-facing change I didn't make without asking. The standard-contrast (default) path is confirmed pixel-identical to before.
- P53/E78 (Full Keyboard Access, Tab-focusable cards): deferred, not a live-check gap. Making cards focusable needs real integration with the Hub's existing custom first-responder keyboard host (arrow keys, number-key quick-paste, and all ⌘-shortcuts funnel through one invisible responder today); bolting on `.focusable()` risks conflicting with that system. Needs a design pass.
- P47/E57 (editor zoom, L), P44/E42 (magnifier loupe), P42/E47 (area-drag modifiers: Space/Shift/Option), P25/E38+E39 (drag into a collection — zero existing `onDrop` support anywhere in the app), P23/E32+E33 (real text-field search, IME/composition-sensitive), P09 (non-activating panel: focus + paste fidelity): genuinely new interaction surface, not bug fixes to existing behavior — needs live interaction session. A render diff can't verify any of these — the open question in each is behavioral, not visual — so they're not attempted blind. Confirmed with team-lead; holding.

[x] P38/E21 (full type-ramp consolidation, batch-12/#79): 34 `.system(size:...)` sites across 6 files (EditorWindowView, HubShelfView, HubView, HubHeaderView, HubListView, HubSupportViews), 21 distinct size/weight/design combinations, consolidated into named `HubTheme.TypeRamp.*` tokens at the exact pixel values already shipped (each documented with its nearest system text style). Not a rollout of the ui-style-guide's 5-role ramp (that guide's roles don't cover ~16 of the 21 combinations in real use) and not a switch to Apple's canonical text-style sizes (would change ~21 pixel values with no practical way to render-verify all of them individually before a release) — the conservative, fully verifiable choice: fix the root cause (scattered magic numbers) with zero visual delta. Render-verified (`HubShelfCardView` for text/link/code/color payloads at min/max card size, plus 4 editor tokens spot-checked standalone; harness deleted before commit).
[x] P31 (batch-11/#78, decided by team-lead for Chen): status-bar left-click already toggled the Hub correctly; the secondary-click modifier was `.option`, fixed to `.control` to match every other menu-bar icon on the Mac.
[x] P04 (batch-11/#78, decided by team-lead for Chen): Hub-open reset `selectedTypeFilter` to `.all` every time; removed — Type is now a preference like Shelf/List/Grid. Selected collection still clears on open (unchanged, not part of the decision).
[x] P33 (batch-11/#78, decided by team-lead for Chen): `openSettings()` never set `.regular`/`.accessory`, and `dismissEditor()` unconditionally reverted to `.accessory` even with Settings still open. Added Settings-window tracking (found by elimination, since the native SwiftUI `Settings` scene has no open/registration hook) and a shared revert that only fires once neither window is open.
[x] P16 (batch-11/#78, decided by team-lead for Chen): VoiceOver's rotor said "Add to Favorites"/"Remove from Favorites" where the right-click menu and empty-state hint both say "Add Favorite"/"Remove Favorite" for the same action — fixed to match. `Export Diagnostics` → `Export Diagnostics…` (opens an `NSSavePanel`, needed its HIG ellipsis). Removed `Start Hidden When Launched at Login`: stored but never read anywhere; decided to remove rather than wire, since even a correct implementation would have no observable effect in this already-Dock-less, no-auto-shown-window accessory app.
[x] P32, P58, P36, post-capture thumbnail (decided by team-lead for Chen, but already fully implemented before this session's batch-11 — verified by reading the code, not re-done, documented in #78): new-install capture shortcut already ⌃⌥⌘S matching ⌃⌥⌘V, with legacy ⇧⌘S preserved for prior users; first-run window already shows both shortcuts read live from `ShortcutStore` plus both permissions with live status; menu-bar icon already a vector template PDF (`menubarIcon.imageset`), render-verified in both light and dark tint; post-capture thumbnail already has click-to-open, swipe-to-dismiss, Reduce-Motion-aware fade, drag-out (`NSDraggingSource`, despite the batch-11 brief saying "no drag-out" — left the working feature in rather than removing it to match a premise that didn't hold), Settings toggle on by default.

[x] P38/E21 (line-height root cause, batch-10/#77): `HubShelfCardView.textLineLimit` divided by a hardcoded "20" pixels-per-line guess, disconnected from the 14pt medium font actually drawn. Added `HubTheme.lineHeight(size:weight:)` (`NSFont.systemFont(...).ascender - .descender + .leading`) and switched the divisor to it. Render-verified (`HubShelfCardView` via `ImageRenderer`, min/max card size × short/long text, harness deleted before commit): no clipping at any size, footer always visible. Note: the real line height (~16.5pt) is less than the old "20", so the new limit is 1-2 lines *higher* at every size, not identical to before — a safe, intentional side effect (less premature truncation), surfaced in the PR body rather than glossed over.
[x] P37/E21's image-preview radius — **decided by team-lead for Chen, reversible: no change.** Unlike the card/window pair (uniform 20pt inset on all four sides, giving an exact 8pt target), the image preview sits inside the card's padded content area with asymmetric insets — 12pt horizontal (content's own side padding) vs. ~38pt vertical (30pt header + 8pt top padding) — and shares no corner with the card's rounded rect at all. There is no uniform inset to subtract from the card's 8pt radius, so concentric math doesn't apply here; forcing one would mean picking an arbitrary axis. Shelf image preview stays 10pt, list thumbnail/fallback stay 12pt. No code change.
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
