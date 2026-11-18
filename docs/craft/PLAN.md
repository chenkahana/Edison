# Edison craft research: plan and checklist

Research only, no app code changes. Outputs live in `docs/craft/`; progress log in `docs/craft/PROGRESS.md`.
Large artifacts (recordings, traces, full-size screenshots) live outside git in `~/tmp/codex/edison-craft/`.
Base: `origin/main` at `f59abfe`. Worktree `~/.worktrees/Edison/craft-research`, branch `docs/craft-research`.

## Checklist

### Setup
- [x] Worktree, PLAN.md, PROGRESS.md, draft PR

### R0 Baseline
- [x] R0.1 Build and run (`swift build`, `swift test`, app launch feasibility)
- [x] R0.2 Code-sweep signals re-run on `origin/main`
- [x] R0.3 Recordings per flow: hotkey summon/dismiss, focus return + paste, search, collections, drag out, capture area/window/full, editor tools, settings, permissions onboarding (script + predictions done; recordings need Chen session)
- [x] R0.4 External display pass
- [x] R0.5 Instruments traces (Hub summon, scroll, search, capture)
- [x] R0.6 `R0-baseline.md`

### R1 Inventory
- [x] R1.1 Surfaces x states x entry/exit transitions x keyboard paths -> `R1-inventory.md`

### R2 Audit (14 checks per surface)
- [x] R2.1 Menu bar item
- [x] R2.2 Hub shelf
- [x] R2.3 Detail pane / preview
- [x] R2.4 Search
- [x] R2.5 Collections
- [x] R2.6 Capture overlay
- [x] R2.7 Editor
- [x] R2.8 Settings
- [x] R2.9 Onboarding / permissions
- [x] R2.10 Share / export
- [x] R2.11 Accessibility passes (VoiceOver, Full Keyboard Access, Reduce Motion, Reduce Transparency, Increase Contrast)
- [x] R2.12 Craft score table (0-3 per surface per check)

### R3 References (mechanics, not looks)
- [x] R3.1 Paste
- [x] R3.2 Raycast clipboard history
- [x] R3.3 Maccy
- [x] R3.4 CleanShot X
- [ ] R3.5 macOS Shift-Cmd-5

### R4 Systems
- [ ] R4.1 Motion tokens
- [ ] R4.2 Haptic map
- [ ] R4.3 Layout tokens
- [ ] R4.4 Type ramp
- [ ] R4.5 Copy rules (English String Catalog)
- [ ] R4.6 State kit

### R5 Backlog
- [ ] R5.1 Scoring
- [ ] R5.2 Workstreams
- [ ] R5.3 PR slices, "needs Chen" marks -> `R5-backlog.md`

---

# Handoff: Edison craft research (2026-11-18)

**Task.** Research only, no code. Find every small thing that keeps Edison from feeling like a utility Apple
shipped with macOS, and turn it into a scored, sequenced backlog for Chen to approve. The same research is running
on Boaz (`~/Boaz/tasks/ux-polish-plan.md`) and Jimmy; use the same rubric and scoring so the three compare.

**Stop point.** After R5 (backlog). Do not implement anything until Chen approves.

---

## 0. Before you start

- **Repo state.** `~/Edison` is on `main`, 12 commits behind `origin/main`, with uncommitted changes in
  `AGENTS.md`, `Edison.xcodeproj/project.pbxproj`, `Edison/App/WindowRouter.swift` and
  `Edison/Core/Capture/CaptureCoordinator.swift`. They're not yours; don't touch, stash or reset them. Work in a fresh
  worktree: `git -C ~/Edison worktree add ~/.worktrees/Edison/craft-research origin/main` (detached is fine for
  research).
- **Read first:** `docs/product.md`, `docs/ui-style-guide.md` (the Paste-inspired shelf spec), `docs/constraints.md`,
  `docs/edison-2.0-plan.md`, `docs/review-checklist.md`, `.codex/memories/lessons.md` and
  `~/.codex/memories/lessons.md`.
- **Product constraints that polish must not break:** paste fidelity (a normal paste keeps every representation the
  source app put on the pasteboard; plain-text paste changes no characters), keyboard-first Hub, menu-bar-only app
  (no Dock icon), local-only data. If a finding's fix would change any of these, mark it "needs Chen".
- **Runtime first.** Every backlog item needs a recording, screenshot or Instruments trace from the running app.
  Code sweeps only point at where to look.

## 1. Starting evidence (stale: local `9be5680`; re-run on `origin/main`)

| Signal | Count | Lead |
|---|---|---|
| `withAnimation` / `.animation(` | 3 | Hub open/close, selection and card changes probably snap. |
| Haptics (`NSHapticFeedbackManager`) | 0 | No trackpad feedback on snaps in the screenshot editor or shelf. |
| `accessibilityReduceMotion` | 0 | |
| `accessibilityLabel` | 6 | VoiceOver likely can't use the Hub or editor. |
| `.font(.system(size:))` | 17 | Check against the style guide's type ramp. |
| `keyboardShortcut` | 6 | Check every Hub and editor action has a key. |
| `ContentUnavailableView` | 1 | Empty, no-results and permission states. |
| `NSUserActivity` / `CSSearchable` / App Intents | 0 | Shortcuts and Spotlight for clipboard items. |

Re-run with:
```sh
for p in 'withAnimation|\.animation\(' 'NSHapticFeedback' 'accessibilityReduceMotion' 'accessibilityReduceTransparency' \
  'accessibilityLabel' '\.font\(\.system\(size' 'keyboardShortcut' 'ContentUnavailableView' 'AppIntent' \
  'Task\.sleep|asyncAfter' 'cornerRadius: *[0-9]' '\.padding\([0-9]'; do
  printf "%-50s %s\n" "$p" "$(rg -c "$p" -g '*.swift' . | awk -F: '{s+=$2} END{print s+0}')"; done
rg -o '\.(spring|snappy|bouncy|smooth|easeInOut|easeOut|easeIn|linear)(\([^)]*\))?' -g '*.swift' . | sed 's/^[^:]*://' | sort | uniq -c | sort -rn
```

## 2. Rubric: what makes a Mac utility feel like a Mac

Answer each check yes/no on every surface (menu bar item, Hub shelf, detail pane, search, collections, screenshot
overlay, editor, settings, onboarding and permission prompts, share/export).

1. **Summon and dismiss.** Hotkey → Hub visible in under 100 ms, every time, including the first after login. The
   Hub appears on the screen with the pointer (or the active window), in the right Space, over full-screen apps.
   Esc or the hotkey again dismisses it, and focus returns to the app that had it, with its selection intact.
   Paste lands in that app without a second click.
2. **Motion with one voice.** A small set of named curves; the shelf slides in from where it lives; selection moves,
   it doesn't blink; cards insert and delete with motion; nothing animates on first show of existing items.
   Reduce Motion turns movement into fades.
3. **Panel behavior.** Correct `NSPanel` style (non-activating where it should be, key when typing), correct
   window level, no flash of an unstyled frame, no stolen focus from the app being pasted into, sensible behavior
   with multiple displays and Stage Manager.
4. **Keyboard everything.** Arrow keys, ⌘1–9 quick paste, Return to paste, ⇧Return or ⌥ for plain text, ⌘F/typing
   to search, ⌘⌫ delete, Space for Quick Look, Tab to move between areas. Every action is in a menu (status menu or
   Hub's menu) with its shortcut shown. Full Keyboard Access reaches everything; focus rings visible.
5. **Direct manipulation.** Drag a card out to any app (with the right types, matching paste fidelity) and into a
   collection; drag files and images in; right-click every card with the same actions as the keyboard.
6. **Screenshot overlay.** Crosshair with live dimensions and a magnifier, smooth at 120 Hz on every display;
   window-capture highlight follows the pointer without lag; Space toggles window/area like macOS; Esc cancels
   cleanly with no leftover overlay; retina-correct output; the capture sound and flash match the system's
   preference.
7. **Editor.** Handles and snapping (with trackpad haptics on snap), ⌘Z/⇧⌘Z for every edit, arrow-key nudging,
   consistent tool cursor, crisp strokes at every zoom, copy and save that never block the UI.
8. **Geometry and type.** Concentric continuous corners, one spacing and radius scale, system text styles, tabular
   digits for times and sizes, truncation that keeps what identifies an item.
9. **Color and materials.** Glass reads well on every wallpaper, in Light, Dark, Increase Contrast and Reduce
   Transparency (solid fallback). Brand orange only for accents, as the style guide says. 4.5:1 for text.
10. **Every state designed.** Empty history, no search results, a collection with nothing in it, permission not
    granted (Screen Recording, Accessibility) with a direct path to the right Settings pane and automatic recovery
    once granted, huge items, images still loading, pasteboard types Edison can't show.
11. **Words.** Title case for buttons and menu items, sentence case for descriptions; real ellipsis for items that
    open a further step; one name per concept. English only (Chen, 2026-11-18): a String Catalog for copy review,
    plurals and grammar agreement, and `FormatStyle` for dates, sizes and counts; no translations.
12. **System citizen.** Launch at login via `SMAppService`, status item with the right template image and states,
    Settings window behaving like a Settings window (⌘, from the menu, remembers the tab), App Intents and
    Shortcuts ("Copy last screenshot", "Paste item N"), Services menu, respects Secure Input and password-manager
    concealed types (`org.nspasteboard.ConcealedType`, `TransientType`).
13. **Speed.** No beachball on large histories or images; search updates every keystroke without lag; memory stays
    flat with 250 items. Measure with Instruments (Animation Hitches, Time Profiler, Allocations).
14. **Accessibility.** VoiceOver can browse, search, paste and capture; actions exposed as custom actions;
    Accessibility Inspector audit clean.

## 3. Phases (same as Boaz)

Write each output under `docs/craft/` in the worktree and send Chen a one-paragraph summary per phase.

- **R0 Baseline:** build, run, record every flow above at 120 Hz in Light and Dark, on the built-in display and an
  external one; Instruments traces for Hub summon, scroll, search and capture. → `R0-baseline.md`
- **R1 Inventory:** every surface × state × entry/exit transition × keyboard path. → `R1-inventory.md`
- **R2 Audit:** every surface through the 14 checks; each finding with evidence, severity, effort, constraint touched.
  → `R2-findings.md`
- **R3 References:** same flows in Paste, Raycast clipboard history, Maccy, CleanShot X, and macOS's own screenshot
  tool (⇧⌘5). Write down mechanics (curve, duration, focus handling, haptics), not looks. → `R3-references.md`
- **R4 Systems:** motion tokens, haptic map, layout tokens, type ramp, copy rules, state kit; reconcile with
  `docs/ui-style-guide.md`. → `R4-systems.md`
- **R5 Backlog:** score, group into workstreams, slice into one-visible-change PRs, mark "needs Chen". Stop.
  → `R5-backlog.md`

## 4. Scoring (shared with Boaz and Jimmy)

Severity (S1 broken or inaccessible, S2 visibly unpolished in a main flow, S3 noticed by a careful user, S4 nit) ×
Reach (every session, daily, occasional, rare) ÷ Effort (S, M, L). Also give each surface a craft score of 0–3 per
rubric check so progress is visible and comparable across the three apps.

## 5. Done when

- `docs/craft/R0`–`R5` exist in the worktree, every finding has evidence, and the backlog is ordered.
- You report: worktree path and branch, the top 10 findings, the systems proposal in five lines, and the questions
  that only Chen can answer.
