# R2 Findings

Every surface through the 14 rubric checks (`PLAN.md` §2). Base `origin/main` `f59abfe`.

**Format.** `ID` · finding · rubric check (1–14) · evidence · Severity (S1 broken/inaccessible, S2 visibly unpolished
in a main flow, S3 noticed by a careful user, S4 nit) · Reach (E every session, D daily, O occasional, R rare) ·
Effort (S, M, L) · Score · constraint touched (PF paste fidelity, KB keyboard-first, MB menu-bar-only, LO local-only,
or none) · status.

**Score** = severity × reach ÷ effort with S1=4, S2=3, S3=2, S4=1; E=4, D=3, O=2, R=1; S=1, M=2, L=4 (same numbers as
the Jimmy and Boaz passes).

**Status.** `code` = confirmed by reading the code path end to end; `verify live` = the code strongly implies it but a
recording must confirm before the PR (R0 scripts F1–F10, D1–D7, T1–T5 name the take). No finding here was observed
in the running app in this pass (see R0 for why). "needs Chen" = the fix would change a product constraint or a
default Chen chose.

## R2.1 Menu bar item (S1)

| ID | Finding | Chk | Evidence | Sev | R | Eff | Score | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|
| E01 | Status menu shows no key equivalents for the global hotkeys: "Open Hub" doesn't show ⇧⌘V, "Capture Screenshot" doesn't show ⇧⌘S, and user-assigned capture shortcuts never appear. The menu is the only place a menu-bar app can teach its keys. | 4 | `StatusBarController.swift:58-64` (all `keyEquivalent: ""`) | S3 | D | S | 6 | KB (helps) | code |
| E02 | Menu-bar icon is a raster bulb with a letter "E" (64/128/256 px PNGs) scaled to 18 pt. On Chen's 1× displays the "E" turns to mush; a template icon should be a vector (PDF/SVG) drawn for 16–18 pt with stroke weights that match SF Symbols. | 8, 12 | `Assets.xcassets/menubarIcon.imageset/Contents.json`, `StatusBarController.swift:50-53`; 18 px downscale at `~/tmp/codex/edison-craft/img/menubar-18px-x4.png` | S3 | E | S | 8 | none | code (downscale simulated); verify live on 1× and 2× |
| E03 | Clicking the status item always opens the menu. The style guide's state map has "menu bar click → shelf"; Paste/Maccy open the history on click and keep the menu on right-click or ⌥-click. | 1, 12 | `StatusBarController.swift:76` (`statusItem.menu = menu`); `docs/ui-style-guide.md` state map | S3 | D | S | 6 | MB | code · needs Chen (click behavior) |
| E04 | Menu titles break Mac conventions: "Settings" has no ellipsis and only works with ⌘, while the menu is open; "Quit" should be "Quit Edison"; "Capture Screenshot" is an area capture (the overlay says "Drag to capture an area"), so "Capture Area" is the clearer name. | 11 | `StatusBarController.swift:60,69,73` | S4 | D | S | 3 | none | code |
| E05 | "Edit Last Screenshot" and "Capture Previous Area" fail silently from the menu when there is nothing to edit or no previous area: the error goes to `captureError`, which only renders inside the Hub banner. The items should be disabled (`validateMenuItem`) when unavailable. | 10 | `AppState.swift:564-568`, `CaptureEngine.swift:50-55`, `HubView.swift:224-241` | S2 | O | S | 6 | none | code |
| E06 | Paused state only dims the icon (`appearsDisabled`), which reads as "Edison is broken" rather than "paused"; no distinct glyph (for example a pause badge) and no state while a capture is in progress or a permission is missing. | 10, 12 | `StatusBarController.swift:40-46` | S4 | O | S | 2 | none | code |
