# R5 Backlog

Base `origin/main` `f59abfe`. Scoring as in R2: severity × reach ÷ effort (S1=4…S4=1; E=4, D=3, O=2, R=1; S=1, M=2,
L=4). Ship order: S1 first, then score. Nothing here is implemented; this is the list for Chen to approve.

**Before any PR:** run the R0 Chen session (≈45 min: F1–F10, D1–D7, T1–T5). 34 of 83 findings are `verify live`;
a PR for one of those starts with its recording, and a finding the recording refutes is dropped.

## R5.1 Ranked findings

| # | ID | Finding | Checks | Sev | Reach | Effort | Score | Constraint | Status |
|---|---|---|---|---|---|---|---|---|---|
| 1 | E07 | Esc doesn't give focus back | 1 | S1 | E | S | 16 | KB | verify live (F1) |
| 2 | E68 | The capture-time "Open System Settings" button doesn't open Settings | 10 | S1 | O | S | 8 | none | verify live (F9) |
| 3 | E73 | Dragging a card out doesn't match paste | 5 | S1 | D | M | 6 | PF | verify live (F5) |
| 4 | E59 | Clear History is one click with no confirmation and no undo | 10, 11 | S1 | R | S | 4 | LO | code |
| 5 | E83 | Paste-back types ⌘K on Dvorak | 1, 12 | S1 | R | S | 4 | PF | code; verify live with the Dvorak layout |
| 6 | E08 | Type-ahead lost while the shelf slides in | 1, 13 | S2 | E | S | 12 | KB | verify live (F1, T1) |
| 7 | E10 | Selection colour depends on the item | 2, 9 | S2 | E | S | 12 | none | code |
| 8 | E17 | Tertiary text fails contrast | 9 | S2 | E | S | 12 | none | code (computed); verify live on bright wallpaper |
| 9 | E31 | The last search sticks | 1, 4 | S2 | E | S | 12 | KB | verify live (F3) |
| 10 | E09 | Shelf can open on the wrong display | 1, 3 | S2 | D | S | 9 | none | verify live (D1) |
| 11 | E14 | Double-click to paste may not register reliably | 4, 5 | S2 | D | S | 9 | none | verify live (F2) |
| 12 | E32 | Space can't be typed into search | 4 | S2 | D | S | 9 | KB | code |
| 13 | E41 | No crosshair | 6 | S2 | D | S | 9 | none | verify live (F6) |
| 14 | E44 | Esc and capture leave focus on Edison | 1, 6 | S2 | D | S | 9 | KB | verify live (F6) |
| 15 | E51 | "Done" can discard | 7, 11 | S2 | D | S | 9 | none | code |
| 16 | E60 | Default hotkeys collide with standard app commands | 12 | S2 | D | S | 9 | KB | code · needs Chen (defaults) |
| 17 | E02 | Menu-bar icon is a blurry raster at 18 pt | 8, 12 | S3 | E | S | 8 | none | code (downscale simulated); verify live on 1× and 2× |
| 18 | E12 | Reduce Motion is ignored | 2, 14 | S3 | E | S | 8 | none | code |
| 19 | E81 | Reduce Motion (duplicate of E12; counted once) | 2, 9, 14 | S3 | E | S | 8 | none | code (counted once with E12 in R5) |
| 20 | E05 | Menu items fail silently when unavailable | 10 | S2 | O | S | 6 | none | code |
| 21 | E16 | Undo delete is mouse-only and short-lived | 4, 10 | S2 | O | S | 6 | KB | code |
| 22 | E19 | Favorites tab empty says "No History Yet" | 10, 11 | S2 | O | S | 6 | none | code |
| 23 | E36 | Deleting a collection is one unlabelled click, no confirmation, no undo | 10, 11, 14 | S2 | O | S | 6 | none | code |
| 24 | E37 | A new collection opens on the wrong empty state | 10, 11 | S2 | O | S | 6 | none | code |
| 25 | E42 | "Show Magnifier and Dimensions" has no magnifier | 6, 11 | S2 | O | S | 6 | none | code |
| 26 | E46 | Capture errors are invisible and mislabelled | 10, 11 | S2 | O | S | 6 | none | code |
| 27 | E69 | Paste without Accessibility explains the wrong thing | 10, 11 | S2 | O | S | 6 | PF, KB | code |
| 28 | E77 | VoiceOver can't tell which card is selected or act on it | 14 | S2 | E | M | 6 | KB | verify live (VoiceOver + Accessibility Inspector on the Hub) |
| 29 | E79 | Editor colour swatches all read "Colour" | 11, 14 | S2 | O | S | 6 | none | code |
| 30 | E01 | Status menu hides the global shortcuts | 4 | S3 | D | S | 6 | KB (helps) | code |
| 31 | E03 | Clicking the status item always opens the menu | 1, 12 | S3 | D | S | 6 | MB | code · needs Chen (click behavior) |
| 32 | E15 | Esc always closes, even mid-search | 4 | S3 | D | S | 6 | KB | code |
| 33 | E18 | Card previews can misstate the content | 8, 10 | S3 | D | S | 6 | PF (display only, but trust) | code |
| 34 | E45 | Capture is silent | 6, 10 | S3 | D | S | 6 | none | code |
| 35 | E53 | Cursors don't follow the tool | 7 | S3 | D | S | 6 | none | code |
| 36 | E54 | No haptics on snap | 7 | S3 | D | S | 6 | none | code |
| 37 | E55 | Save blocks the app | 7, 13 | S3 | D | S | 6 | none | code |
| 38 | E43 | Pointer tracking does heavy work per move | 6, 13 | S2 | D | M | 4.5 | none | verify live (T4, D5) |
| 39 | E52 | No menu bar while editing | 4, 12 | S2 | D | M | 4.5 | MB | verify live (F7: ⌘W) · needs Chen |
| 40 | E11 | Motion has three voices and snaps where it matters | 2 | S3 | E | M | 4 | none | code; verify live (F1, F3) |
| 41 | E20 | Header is crowded and fixed-width | 8 | S3 | E | M | 4 | none | verify live (F1 screenshot) |
| 42 | E21 | Geometry isn't concentric and type isn't the ramp | 8 | S3 | E | M | 4 | none | code |
| 43 | E23 | ⇧Return on a non-text item does nothing, silently | 4, 10 | S3 | O | S | 4 | PF | code |
| 44 | E34 | Search runs several times per render | 13 | S3 | O | S | 4 | none | verify live (T3) |
| 45 | E61 | A toggle that does nothing | 10, 11 | S3 | O | S | 4 | none | code |
| 46 | E64 | Copy drift | 11 | S3 | O | S | 4 | none | code |
| 47 | E65 | Permission status goes stale | 10 | S3 | O | S | 4 | none | verify live (F9) |
| 48 | E66 | Storage size is recomputed on the main thread after every settings change | 13 | S3 | O | S | 4 | none | verify live (F8) |
| 49 | E74 | Share sends less than the item and points at nothing | 5, 10 | S3 | O | S | 4 | PF | code |
| 50 | E75 | Export is generic and can stall | 10, 11, 13 | S3 | O | S | 4 | PF | code |
| 51 | E24 | Timestamps never become dates | 11 | S4 | E | S | 4 | none | code |
| 52 | E13 | Hub steals activation from the app being pasted into | 3 | S2 | E | L | 3 | PF, KB (paste-back path) | code · needs Chen (architecture of paste-back) |
| 53 | E22 | Rendering work on every frame | 13 | S2 | O | M | 3 | none | verify live (T2) |
| 54 | E27 | Quick Look may close the Hub | 3, 4 | S2 | O | M | 3 | KB | verify live (F3) |
| 55 | E62 | Restore Defaults has no confirmation | 10 | S2 | R | S | 3 | none | code |
| 56 | E71 | No recovery after granting Screen Recording | 10 | S2 | R | S | 3 | none | verify live (F9) |
| 57 | E78 | Full Keyboard Access can't reach the cards | 4, 14 | S2 | O | M | 3 | KB | verify live (FKA on, Tab through the Hub) |
| 58 | E35 | Results give no feedback | 2, 10 | S3 | D | M | 3 | none | code |
| 59 | E47 | Space mid-drag throws the selection away | 6 | S3 | D | M | 3 | none | code |
| 60 | E56 | Copy renders on the main thread | 7, 13 | S3 | D | M | 3 | none | verify live (T4) |
| 61 | E04 | Menu titles break Mac conventions | 11 | S4 | D | S | 3 | none | code |
| 62 | E25 | Layout and filter reset on relaunch | 12 | S4 | D | S | 3 | none | code |
| 63 | E49 | Overlay chrome is loud and off-system | 6, 9 | S4 | D | S | 3 | none | verify live (F6) |
| 64 | E76 | Editor drag-out renders at drag start | 5, 13 | S4 | D | S | 3 | none | verify live (F7) |
| 65 | E57 | No zoom | 7 | S2 | D | L | 2.25 | none | code |
| 66 | E26 | Possible empty-state flash on the first open after launch | 10 | S3 | R | S | 2 | none | verify live (F1 first-after-login) |
| 67 | E28 | Arrow keys don't move through history while previewing | 4 | S3 | O | M | 2 | KB | code |
| 68 | E29 | Previews flatten rich content | 10 | S3 | O | M | 2 | PF (display only) | code |
| 69 | E33 | Type-to-search bypasses text input | 4, 14 | S3 | O | M | 2 | KB | code |
| 70 | E38 | No drag into a collection, no drag in at all | 5 | S3 | O | M | 2 | none | code |
| 71 | E39 | Collections are mouse-only | 4 | S3 | O | M | 2 | KB | code |
| 72 | E48 | The frozen frame isn't what gets captured | 6 | S3 | O | M | 2 | none | verify live (F6) |
| 73 | E63 | Not shaped like a Mac Settings window | 12 | S3 | O | M | 2 | none | verify live (F8) |
| 74 | E72 | App-modal alerts from a background menu-bar app | 3, 10 | S3 | O | M | 2 | none | verify live (F9) |
| 75 | E80 | No Increase Contrast variants | 9, 14 | S3 | O | M | 2 | none | verify live (Increase Contrast on) |
| 76 | E06 | Paused status icon reads as broken | 10, 12 | S4 | O | S | 2 | none | code |
| 77 | E30 | Quick Look is undiscoverable and rewrites its file every render | 4, 13 | S4 | O | S | 2 | none | code |
| 78 | E40 | Small feedback gaps | 10, 11 | S4 | O | S | 2 | none | code |
| 79 | E58 | Each arrow-key nudge is its own undo step | 7 | S4 | O | S | 2 | none | code |
| 80 | E70 | No first run | 10, 12 | S2 | R | M | 1.5 | MB | code |
| 81 | E50 | A selection that crosses displays is cut at the edge | 6 | S3 | R | M | 1 | none | verify live (D4) |
| 82 | E67 | History limit is a 25-step stepper from 25 to 1000 | 8, 12 | S4 | R | S | 1 | LO | code |
| 83 | E82 | Annotations and the canvas are invisible to VoiceOver | 14 | S3 | R | L | 0.5 | none | code |

## R5.2 Workstreams

Each finding belongs to exactly one workstream. Score sum adds member scores (E81 counts 0: it duplicates E12).

| WS | Name | Scope | Findings | S1s | Count | Score sum | Depends on |
|---|---|---|---|---|---|---|---|
| W0 | Summon, focus and paste-back | Every exit returns focus; key on frame one; pointer display; fresh state on open; layout-safe ⌘V; Quick Look keeps the Hub | E07, E08, E09, E14, E15, E27, E31, E44, E83, E13 | E07, E83 | 10 | 83 | R0 F1–F3, D1. E13 (non-activating panel) needs Chen |
| W1 | Motion system | R4.1 tokens, content-not-window entrance, selection ring motion, insert/delete, Reduce Motion | E11, E12, E81 | – | 3 | 12 | R4.1; after W0 (shares the open path) |
| W2 | Pointer and haptics | Editor cursors and haptic map | E53, E54 | – | 2 | 12 | R4.2 |
| W3 | Geometry, type and colour | Layout tokens, single selection ring, text-style ramp, contrast, header layout, vector status icon | E02, E10, E17, E20, E21 | – | 5 | 40 | R4.3, R4.4 |
| W4 | States and copy | State kit, confirmations, error placement, String Catalog, glossary, FormatStyle, retention control | E04, E05, E06, E16, E19, E23, E24, E26, E36, E37, E40, E42, E46, E51, E59, E61, E62, E64, E65, E67, E68, E69, E71, E72 | E59, E68 | 24 | 107 | R4.5, R4.6 |
| W5 | Mac nativeness | Menus with shortcuts, real search field, drag in/out with paste fidelity, collections by keyboard, sheets, Settings shape | E01, E03, E25, E28, E29, E30, E32, E33, E35, E38, E39, E52, E55, E58, E60, E63, E73, E74, E75, E76 | E73 | 20 | 79.5 | R2; E03, E52, E60 need Chen |
| W6 | Capture and editor | Crosshair, loupe, macOS drag modifiers, feedback HUD + sound, frozen-frame consistency, cross-display clamp, zoom | E41, E45, E47, E48, E49, E50, E57 | – | 7 | 26.25 | R3.4, R3.5 |
| W7 | System integration | First run; later App Intents ("Copy Last Screenshot", "Paste Item N"), Services | E70 | – | 1 | 1.5 | After W4; App Intents are new scope, need Chen |
| W8 | Speed | Per-render parsing, search memoisation, overlay tracking, off-main rendering and I/O | E18, E22, E34, E43, E56, E66 | – | 6 | 24.5 | R0 T1–T5 numbers first |
| W9 | Accessibility | VoiceOver labels/actions/selected, Full Keyboard Access, Increase Contrast, canvas | E77, E78, E79, E80, E82 | – | 5 | 17.5 | W3 (contrast tokens), W1 (Reduce Motion) |

**Order.** W0 first: it holds the top-ranked S1 (E07) and the structural choice (E13) that W1 builds on. Then W4
(three S1s, mostly small), the W5 drag-fidelity slice (E73, S1), W3, W1, W6, W8, W9, W2, W7. W8 can run alongside
once the R0 traces exist.
