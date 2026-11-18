RESUME HERE: R2.1 audit menu bar item: start docs/craft/R2-findings.md with finding format (ID, surface, check, evidence, severity, reach, effort, score, constraint, verify-live) and menu bar findings.

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
| 2026-11-18 | R1.1 inventory | R1-inventory.md: 11 surfaces, states + missing states, entry/exit motion, keyboard maps (Hub, overlay, editor, global), naming conflicts | (this commit) |
