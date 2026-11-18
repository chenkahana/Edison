RESUME HERE: R4.5 copy rules: English String Catalog (Localizable.xcstrings, en only), title/sentence case, ellipsis, one name per concept glossary (Hub, Area, Pixelate, Favorite), FormatStyle + plural rules, error/permission copy patterns.

# Progress log (append-only)

| Date | Step | Done | Commit |
|---|---|---|---|
| 2026-11-18 | Setup | Worktree `~/.worktrees/Edison/craft-research` on `docs/craft-research` from `origin/main` `f59abfe`; PLAN.md (handoff + checklist), PROGRESS.md | 1037942 |
| 2026-11-18 | R0.1 build and run | swift build/test pass (44 tests); installed build 4 running, live run needs Chen session; R0-baseline.md started | 5e61c2f |
| 2026-11-18 | R0.2 code-sweep signals | Signal table re-run on f59abfe (35 fixed font sizes, 0 haptics, 0 reduce-motion, 0 App Intents, no String Catalog, no NSPanel) | cc7e477 |
| 2026-11-18 | R0.3 flow recording script | 10-flow recording script with code-traced predictions (F1-F10); recordings need Chen session | 514137a |
| 2026-11-18 | R0.4 external display pass | Display inventory (2x Dell 1080p 1x 60Hz, built-in off); D1-D7 multi-display script + predictions; takes need Chen session | 5ee3fff |
| 2026-11-18 | R0.5 Instruments trace plan | xctrace commands T1-T5 + existing signposts + 8 code-traced hotspots; traces need Chen session | 24cb635 |
| 2026-11-18 | R0.6 baseline summary | R0-baseline.md summary: what ran, what needs Chen, six strongest predictions | cf221d7 |
| 2026-11-18 | R1.1 inventory | R1-inventory.md: 11 surfaces, states + missing states, entry/exit motion, keyboard maps (Hub, overlay, editor, global), naming conflicts | df1ee75 |
| 2026-11-18 | R2.1 menu bar findings | R2-findings.md started: format + scoring (S1=4..S4=1, E/D/O/R=4..1, S/M/L=1/2/4); E01-E06 menu bar item | be1c5f9 |
| 2026-11-18 | R2.2 Hub shelf findings | E07-E26 Hub shelf (Esc focus return S1, type-ahead loss, wrong display, selection colour, contrast, motion, perf) | ac0aa08 |
| 2026-11-18 | R2.3 detail/preview findings | E27-E30 Quick Look (may dismiss Hub, single-item datasource, flattened rich previews, discoverability) | dd8d9c3 |
| 2026-11-18 | R2.4 search findings | E31-E35 search (query never resets, space blocked, IME/option chars, repeated filtering, no highlights) | 9f1a62c |
| 2026-11-18 | R2.5 collections findings | E36-E40 collections (unconfirmed delete, wrong empty state, no drop targets, mouse-only, menu check marks) | 7f235ce |
| 2026-11-18 | R2.6 capture overlay findings | E41-E50 capture overlay (no crosshair, phantom magnifier setting, per-move window list + full redraw, focus after Esc, silent capture, hidden errors) | 9f301ce |
| 2026-11-18 | R2.7 editor findings | E51-E58 editor (Done can discard, no menu bar, cursors, no haptics, app-modal save, main-thread render, no zoom, nudge undo) | 094f14b |
| 2026-11-18 | R2.8 settings findings | E59-E67 settings (unconfirmed Clear History S1, hotkey collisions, dead toggle, stale permissions, main-thread storage walk, copy drift) | d56a0fb |
| 2026-11-18 | R2.9 onboarding/permissions findings | E68-E72 permissions (capture alert button is a no-op after first prompt S1, AX fallback copy, no first run, no relaunch recovery, app-modal alerts) | 82e8700 |
| 2026-11-18 | R2.10 share/export findings | E73-E76 share/export (drag-out types vs paste fidelity S1, share anchor/rich loss, export naming + main-thread file read, editor drag render) | bf1e339 |
| 2026-11-18 | R2.11 accessibility findings | E77-E82 accessibility (VO selection/actions, FKA can't reach cards, swatch labels, Increase Contrast, RM/RT coverage, canvas) | 61c4dbd |
| 2026-11-18 | R2.12 craft score table | Provisional 0-3 scores, 10 surfaces x 14 checks; app 143/306 (47%); Hub 39%, Collections 33% | 96411fa |
| 2026-11-18 | R3.1 Paste reference | R3-references.md started: sources legend (src/bundle/known/measure), installed refs (Raycast only), Paste mechanics vs Edison + takeaways | 3511088 |
| 2026-11-18 | R3.2 Raycast reference | Raycast clipboard history mechanics (focus return, real search field, Esc ladder, action panel, toast fallback) | 5314646 |
| 2026-11-18 | R3.3 Maccy reference | Maccy mechanics from source (nonactivating panel, instant key, positions, reset on close, layout-mapped paste); new finding E83 added to R2 | 8ff449a |
| 2026-11-18 | R3.4 CleanShot X reference | CleanShot X mechanics (loupe, selection adjust, freeze, Quick Access Overlay, sound, window highlight, editor zoom) | 76bfb51 |
| 2026-11-18 | R3.5 macOS screenshot reference | macOS Shift-Cmd-3/4/5 mechanics vs Edison overlay (cursor, drag modifiers, window mode, cancel focus, sound+thumbnail, multi-display) | 87e978e |
| 2026-11-18 | R4.1 motion tokens | R4-systems.md started: 4 motion tokens (quick/standard/emphasized/gesture), content-not-window rule, Reduce Motion resolver, call-site map, style guide reconciliation | ac7babf |
| 2026-11-18 | R4.2 haptic map | Haptic map: editor snaps (.alignment), crop edge (.generic), collection drop target; none for keyboard/Hub list | 6eb6d4b |
| 2026-11-18 | R4.3 layout tokens | Layout tokens: derived concentric radii (28/12/16/4), control radius 8, spacing lint rule, shelf 278 reconciled, single selection ring, hit.min 28, lighter card shadow | fec2673 |
| 2026-11-18 | R4.4 type ramp | Type ramp: 12 roles mapped to macOS text styles, truncation rules, tabular-digit list, guide reconciliation | (this commit) |
