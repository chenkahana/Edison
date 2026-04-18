# Edison v1.5 Work Plan: Stability, Performance, and Code Cleaning

**Date:** 2026-04-18
**Author:** Planner (consensus-ready)
**Revision:** 2 (2026-04-18 -- addresses Architect ITERATE + Critic ITERATE feedback)
**Branch base:** `chenk/paste-back-selected-item` (4534bba) or merge to `main` first
**Scope:** Internal quality. Zero new user-facing features.

---

## 1. Requirements Summary

Edison v1.5 is a **stability, performance, and code-cleaning release**. It ships no new features, no UI redesigns, and no product scope changes. The goals are:

- **Reduce maintenance burden** by decomposing the two largest files (`AppState.swift` at 838 lines, `HubView.swift` at 1636 lines) into focused, testable units.
- **Expand test coverage** to untested areas (CaptureEngine, PasteBackCoordinator timing, WindowRouter lifecycle, AppState observer teardown).
- **Establish performance baselines** so future releases can prove "no regression" with data, not intuition.
- **Audit stability edges** (observer lifecycles, retain cycles, window lifecycle race conditions).
- **Clean up untracked work** from v1.1 (Settings subsystem, ScreenshotDocument, CodableColor, ShortcutValidator) by committing or discarding.

**Explicit exclusions:** No new features. No UI redesigns. No cloud/sync. No AI/OCR. No dependency additions. No new architecture layers (no DI container, no TCA, no coordinator pattern).

---

## 2. RALPLAN-DR Summary

### 2.1 Principles (5)

| # | Principle | Rationale |
|---|-----------|-----------|
| P1 | **Measure before optimizing** | No performance change ships without before/after Instruments data. "Should be faster" is not evidence. |
| P2 | **No new abstractions without clear need** | Per `docs/constraints.md`. Extracted types must reduce complexity, not add indirection. |
| P3 | **Preserve behavior exactly** | Every refactor must pass the existing test suite + new golden-path tests before and after. Golden tests are defined in Section 4.1. |
| P4 | **Tests land with refactors** | No refactor PR merges without accompanying tests that cover the extracted code. |
| P5 | **Ship incrementally** | Each workstream is independently mergeable. No "big bang" branch that diverges for weeks. |

### 2.2 Decision Drivers (Top 3)

| Priority | Driver | Metric |
|----------|--------|--------|
| 1 | **Stability** | Zero new crashes. Observer lifecycle audit passes manual review. All tests green. |
| 2 | **Responsiveness** | Hub open-time p95 measured via `os_signpost`; target: post-refactor p95 must not exceed W1.5 baseline median by more than 20% (see AC7). Memory: no growth after 1000 clipboard items in test harness. |
| 3 | **Maintainability** | `AppState.swift` approximately <= 500 lines. `HubView.swift` <= 800 lines. Test file count >= 6. Coverage for PasteBack, WindowRouter, CaptureEngine. |

### 2.3 Viable Options

#### Option A: Targeted Hardening (RECOMMENDED)

Decompose `AppState` (extracting `ClipboardCoordinator` and `CaptureCoordinator`; paste-back methods stay in AppState behind a MARK section since `PasteBackCoordinator` already handles orchestration), split `HubView` into sub-views, add missing tests, establish performance baselines. Keep CaptureEngine as-is (it works and has no reported bugs). No protocol extraction for capture paths.

| Pros | Cons |
|------|------|
| Addresses the two largest maintenance risks (AppState, HubView) with bounded effort | Leaves CaptureEngine at 662 lines (manageable but not small) |
| Test coverage expands to the three untested areas most likely to regress | Does not introduce a capture abstraction for future testability |
| Performance baselines prevent silent regressions in future releases | Requires discipline to not scope-creep into CaptureEngine |
| Independently mergeable workstreams (P5) | -- |
| Estimated effort: 3-4 focused work sessions | -- |

#### Option B: Broader Refactor

Everything in Option A, plus: extract CaptureEngine into a protocol (`CaptureProviding`) with `SCKCaptureProvider` and `LegacyCaptureProvider` conformances. Reorganize test directory by domain.

| Pros | Cons |
|------|------|
| CaptureEngine becomes independently testable with mock providers | Adds a protocol + 2 conformances = new abstraction layer (violates P2 without clear need today) |
| Test directory becomes cleaner with per-domain files | More merge risk; larger diff surface |
| Future-proofs capture path for macOS API changes | Estimated effort: 5-7 sessions -- 40-75% more than Option A |

#### Option C: Minimal (Tests + Profiling Only, No Refactors)

Add tests for untested areas, add `os_signpost` instrumentation, measure baselines. Do not touch AppState or HubView structure.

| Pros | Cons |
|------|------|
| Lowest risk; smallest diff | Does not address the 838-line / 1636-line maintenance debt |
| Fast to ship | AppState remains hard to test in isolation (18 @Published properties, ~40 methods in one type) |
| -- | HubView remains a 1636-line monolith with 9 @State properties + 1 @FocusState and 16 private structs/enums inlined |

**INVALIDATION:** Option C is not recommended because the primary complaint motivating v1.5 is maintainability debt in AppState and HubView. Shipping only tests and measurements does not reduce that debt, and the test harness for AppState is already awkward due to its 7-parameter initializer and mixed concerns. Tests written against the current monolith would need rewriting after a future decomposition, violating P5 (ship incrementally -- invest once).

### 2.4 Recommendation

**Option A: Targeted Hardening.** It addresses the highest-impact debt (AppState, HubView) with bounded scope, keeps CaptureEngine untouched (it works, 662 lines is not critical), and each workstream merges independently.

---

## 3. Acceptance Criteria

| ID | Criterion | Verification |
|----|-----------|-------------|
| AC1 | `AppState.swift` reduced from 838 to approximately <= 500 lines by extracting `ClipboardCoordinator` and `CaptureCoordinator` (paste-back methods remain in AppState with a `// MARK: - Paste Back` section, delegating to the existing `PasteBackCoordinator`) | `wc -l Edison/App/AppState.swift` (approximate target, not a hard gate) |
| AC2 | Extracted coordinators are `@MainActor` types owned by `AppState`; no new singletons or DI containers | Code review |
| AC3 | `HubView.swift` reduced from 1636 to <= 800 lines by extracting `HubShelfView`, `HubListView`, `HubGridView`, `HubSearchBar`, `HubHeaderView` as separate files | `wc -l Edison/UI/Hub/HubView.swift` |
| AC4 | Test file count >= 6 (split `EdisonTests.swift` by domain: Search, Clipboard, PasteBack, Shortcuts, Capture, Collections) | `ls Edison/Tests/` |
| AC5 | New tests: PasteBackCoordinator timing (>= 3 cases covering success, timeout, accessibility-denied), WindowRouter open/close/toggle, AppState observer setup and teardown | `swift test` output shows new test names |
| AC6 | `os_signpost` intervals added for: Hub window open, search filter execution, history load, capture start-to-result | Instruments trace shows named intervals |
| AC7 | Post-refactor p95 hub open time, p95 search filter time, and p95 history load time must not exceed W1.5 baseline median by more than 20%. If exceeded, investigate and either fix or document the reason in `docs/performance-baselines.md`. | Instruments capture with 1000+ items; comparison against W1.5 baseline |
| AC8 | Memory baseline: measured after 1000 clipboard items added in test harness; documented; no unbounded growth | Instruments Allocations trace |
| AC9 | All force unwraps reviewed: 2 in HubView (system URL + QLPreviewPanel) documented as safe; 7 in test helpers documented as acceptable | Comment in code or docs |
| AC10 | Zero compiler warnings in Release build. Enforced via `GCC_TREAT_WARNINGS_AS_ERRORS=YES` in an `.xcconfig` for the Release configuration. No SPM dependency added. | `xcodebuild -scheme Edison -configuration Release build` must exit 0 with no `warning:` in output |
| AC11 | Untracked files (Settings/, ScreenshotDocument, CodableColor, ShortcutValidator) either committed with tests or explicitly deferred with rationale | `git status` clean |
| AC12 | `swift test` passes on CI and local | Exit code 0 |
| AC13 | Manual smoke: paste-back, capture (area + window + full), search with 10k items, editor open/close, settings round-trip. QA checklist executed and initialed by the author in the PR description for W7. | QA checklist in W7 PR description |

---

## 4. Golden Tests Definition

Golden tests are the behavior-preservation safety net for W2 and W3 refactors. They consist of:

- **W4a tests (pre-refactor):** PasteBackCoordinator timing tests (success, timeout, accessibility-denied), AppState lifecycle tests (init without runtime services, deinit observer cleanup, settings round-trip), and the split test files preserving all existing test coverage.
- **W4b tests (post-refactor):** ClipboardCoordinator unit tests and CaptureCoordinator unit tests, exercising the new types' public surfaces.

"Preserve behavior exactly" (P3) is verified by: all pre-existing tests green + all golden tests green + manual QA checklist pass. If any golden test fails after a refactor step, the refactor must be fixed or reverted before proceeding.

---

## 5. Implementation Steps (by Workstream)

### W1: Instrumentation and Baselines (do FIRST -- measure before changing)

**Rationale:** P1 requires measurements before any refactor. This workstream produces the "before" data.

**PR granularity:** 1 PR (instrumentation + baselines doc).

| Step | File(s) | Action | Acceptance |
|------|---------|--------|------------|
| W1.1 | `Edison/App/AppState.swift` (lines 573-584: `toggleHubFromShortcut`) | Add `os_signpost(.begin/.end)` around hub toggle flow, measuring time from shortcut invocation to window visible | Signpost appears in Instruments under "Edison Hub" category |
| W1.2 | `Edison/Core/Persistence/HistoryStore.swift` (line ~20: `loadAsync`) | Add signpost around history load completion callback | Signpost shows load duration in Instruments |
| W1.3 | `Edison/App/AppState.swift` (lines 65-78: `filteredItems` computed property) | Add signpost around search/filter execution | Signpost shows filter duration per keystroke |
| W1.4 | `Edison/Core/Capture/CaptureEngine.swift` (line 30: `capture(_:settings:)`) | Add signpost from capture request to result | Signpost shows end-to-end capture latency |
| W1.5 | New file: `docs/performance-baselines.md` | Run Instruments with 1000+ items in history; document p50/p95 for hub open, search, history load, capture. Capture Allocations baseline. **Measurement protocol:** 3 warm-state trials, discard first, report median. Warm state = app open >= 5s with 1000 items loaded. Seed history via test harness script. Measurements taken on the same physical hardware as the comparison run. | File exists with real numbers, dated, tied to commit hash |

### W2: AppState Decomposition

**Rationale:** `AppState.swift` is 838 lines with 18 `@Published` properties and ~40 methods spanning 4 distinct concerns (clipboard management, capture coordination, collection management, settings/permissions). This makes isolated testing impractical and increases cognitive load for every change. Paste-back orchestration is already handled by `PasteBackCoordinator` (139 lines); the thin wrapper methods in AppState stay put.

**PR granularity:** 2 PRs (one per coordinator: ClipboardCoordinator first, then CaptureCoordinator).

**`suppressedClipboardPayloads` ownership:** The set at `AppState.swift:54` is read by `addToHistory` (line 518) and written by `writeItemToClipboard` (line 629) and `writeImageDataToClipboard` (line 761). Decision: `suppressedClipboardPayloads` lives in `ClipboardCoordinator`. `CaptureCoordinator` receives a closure `suppressClipboardPayload: (ClipboardPayload) -> Void` injected at init (mirroring the existing `PasteBackCoordinator` injection pattern). `writeItemToClipboard` moves to `ClipboardCoordinator`; `writeImageDataToClipboard` stays in `CaptureCoordinator` but uses the injected closure to write to the suppression set.

| Step | File(s) | Action | Acceptance |
|------|---------|--------|------------|
| W2.1 | New: `Edison/Core/Clipboard/ClipboardCoordinator.swift` | Extract from `AppState`: `addToHistory` (line 517), `persistHistory` (544), `trimHistoryToSettingsLimit` (548), `writeItemToClipboard` (628), `deleteItem` (296), `undoDelete` (324), `toggleFavorite` (290), `promoteItemToFront` (355), `clearHistory` (472), clipboard monitor setup (lines 136-140), the `historyItems`/`deletedItemForUndo`/`showDeleteUndoToast` published properties, and `suppressedClipboardPayloads`. `ClipboardCoordinator` is `@MainActor`, `ObservableObject`, owned by `AppState`. | `ClipboardCoordinator` compiles, `AppState` delegates to it, all existing tests pass |
| W2.2 | New: `Edison/Core/Capture/CaptureCoordinator.swift` | Extract from `AppState`: `startCapture` (line 666), `handleCaptureResult` (672), `openEditor` (706), `commitScreenshotSession` (712), `persistScreenshotImage` (731), `writeImageDataToClipboard` (760), `presentScreenRecordingPermissionAlert` (767), and the `activeScreenshotSession`/`lastScreenshotSession`/`captureError`/`screenRecordingAccessGranted`/`lastCaptureFailureReason` published properties. `CaptureCoordinator` receives `suppressClipboardPayload: (ClipboardPayload) -> Void` closure at init to write to `ClipboardCoordinator.suppressedClipboardPayloads`. | `CaptureCoordinator` compiles, `AppState` delegates to it, capture smoke test passes |
| W2.3 | `Edison/App/AppState.swift` | Remaining in `AppState`: published properties that are view-model concerns (`activeQuery`, `selectedTypeFilter`, `selectedCollectionID`, `settings`, `showEditorDiscardAlert`, `failedShortcutActions`, `launchAtLoginStatusDescription`, `launchAtLoginErrorMessage`), collection CRUD (lines 240-288), settings/shortcuts save (lines 223-238), permission methods (189-202), `filteredItems`/`favoriteItems` computed properties, `init`, `deinit`, hotkey dispatch. Paste-back methods (`pasteResolvedItem`, `finishPasteBack`, `capturePasteBackTargetApp`, `clearPasteBackContext`, `copyToClipboard`, `pasteItem`, `pasteSelection`) remain with a `// MARK: - Paste Back` section marker. Target: approximately <= 500 lines. | `wc -l` approximately <= 500; all tests pass; no behavioral change |

### W3: HubView Decomposition

**Rationale:** `HubView.swift` is 1636 lines containing 16 private structs/enums, 3 layout modes (shelf/list/grid), search bar logic, collection management UI, Quick Look bridging, and a custom NSViewRepresentable keyboard handler. Extracting layout-specific views reduces per-file cognitive load and enables targeted SwiftUI previews.

**PR granularity:** 2 PRs (headers + support views first; shelf/list views second).

| Step | File(s) | Action | Acceptance |
|------|---------|--------|------------|
| W3.1 | New: `Edison/UI/Hub/HubShelfView.swift` | Extract `HubShelfCardView` (line 863) and its supporting types (`HubCardFooter` at 1081, `HubImagePreviewView` at 1044) | File compiles; shelf layout renders identically (visual check) |
| W3.2 | New: `Edison/UI/Hub/HubListView.swift` | Extract `HubListRowView` (line 740) and list-specific layout code from `contentColumn` (line 400) | File compiles; list layout renders identically |
| W3.3 | New: `Edison/UI/Hub/HubHeaderView.swift` | Extract `header` (line 223), `filterControls` (248), `collectionControls` (260), `trailingControls` (270), `searchPill` (278), `filterPicker` (297), `typePicker` (307), `layoutPicker` (317), `newCollectionComposer` (328), `collectionMenu` (348) | File compiles; header renders identically |
| W3.4 | New: `Edison/UI/Hub/HubSupportViews.swift` | Extract `ContentSizeReader` (721), `HubWindowAccessor` (1300), `QuickLookBridge` (1561), `HubToastView` (1487), `HubCaptureErrorBanner` (1516), `HubItemIconView` (1098), `ClipboardSourceApplicationIconProvider` (1277), `HubClipboardTextView` (1007) | File compiles; all supporting views work |
| W3.5 | `Edison/UI/Hub/HubView.swift` | Remaining: `HubView` struct with `body`, `mainContent`, `contentColumn` (delegating to extracted layout views), state properties, keyboard/selection logic, `emptyState`. Target: <= 800 lines. | `wc -l` <= 800; all manual smoke tests pass; no visual diff |

### W4a: Test Foundation (runs BEFORE W2 -- tests against current monolith)

**Rationale:** Per P3 and P4, golden tests must exist before refactoring begins. These tests exercise existing behavior so regressions are caught during extraction.

**PR granularity:** 1 PR (test file split + new tests on current code).

| Step | File(s) | Action | Acceptance |
|------|---------|--------|------------|
| W4a.1 | Split `Edison/Tests/EdisonTests.swift` into domain files | Create: `SearchTests.swift` (search/filter tests), `ClipboardTests.swift` (monitor type handling, round-trips), `PasteBackTests.swift` (existing paste-back + new), `ShortcutTests.swift` (migration, validator), `CaptureTests.swift` (screenshot session undo/redo, commit), `CollectionTests.swift` (if collection tests exist or add basic ones). **Note:** Current `EdisonTests.swift` uses both `#if canImport(Testing)` (Swift Testing) and `#if canImport(XCTest)` (XCTest) blocks. The split must preserve both frameworks in each new file, or make an explicit decision to drop one. Preserving both is the low-risk default. | >= 6 test files; `swift test` passes; no test removed |
| W4a.2 | `Edison/Tests/PasteBackTests.swift` | Add >= 3 new PasteBackCoordinator timing tests: (1) successful paste-back completes within tolerance, (2) paste-back with accessibility denied skips Cmd+V and shows alert, (3) paste-back when target app is nil gracefully falls back to copy-only. Use real clock, document tolerances. | 3 new `@Test` functions; all pass |
| W4a.3 | `Edison/Tests/AppStateLifecycleTests.swift` (new) | Test: `AppState(enableRuntimeServices: false)` does not start clipboard monitor; `deinit` removes observers (verify via NotificationCenter post after dealloc); settings round-trip persists and reloads. These test AppState's current monolithic surface. | >= 3 test cases; all pass |

### W4b: Coordinator Tests (runs AFTER W2 -- tests for extracted types)

**Rationale:** Once `ClipboardCoordinator` and `CaptureCoordinator` exist as standalone types, they need isolated unit tests exercising their public surfaces.

**PR granularity:** Folds into W2 PRs (tests land with the extracted type).

| Step | File(s) | Action | Acceptance |
|------|---------|--------|------------|
| W4b.1 | `Edison/Tests/ClipboardCoordinatorTests.swift` (new) | Test `ClipboardCoordinator` in isolation: add/delete/undo history items, clipboard suppression set behavior, trim to limit. Lands with the W2.1 PR. | >= 3 test cases; all pass |
| W4b.2 | `Edison/Tests/CaptureCoordinatorTests.swift` (new) | Test `CaptureCoordinator` in isolation: capture result handling, screenshot session lifecycle, suppression closure integration. Lands with the W2.2 PR. | >= 3 test cases; all pass |
| W4b.3 | `Edison/Tests/WindowRouterTests.swift` (new) | Test: `toggleHub` opens when closed, closes when open; `registerHubWindow` applies shelf style; `dismissHub` clears state; `openEditor`/`closeEditor` lifecycle. Mock `NSWindow` where needed. | >= 4 test cases; all pass |

### W5: Stability Audit

**Rationale:** `AppState.deinit` (lines 168-181) does async cleanup in a `Task { @MainActor }` block, which may not execute if the process is terminating. Observer lifecycle edges need manual review.

**PR granularity:** 1 PR (audit fixes + comments).

| Step | File(s) | Action | Acceptance |
|------|---------|--------|------------|
| W5.1 | `Edison/App/AppState.swift` (lines 168-181) | Review `deinit` async observer removal. If `deinit` races with process exit, observers may leak. Evaluate whether synchronous removal is safe or if the concern is moot (process exit cleans up). Document decision in code comment. | Comment added explaining the tradeoff; no crash in manual test of quit-during-paste |
| W5.2 | `Edison/App/AppState.swift` (lines 155-165) | Review `activeAppObserver` for retain cycle: closure captures `[weak self]` (correct). Verify `shortcutActionRequestObserver` (line 142) also uses `[weak self]` (it does). Verify `clipboardMonitor.start` callback (line 136) uses `[weak self]` (it does). | Audit documented; no retain cycles found (or fixed if found) |
| W5.3 | `Edison/App/WindowRouter.swift` | Review `weak var hubWindow` / `weak var storedEditorWindow` — confirm windows are not prematurely deallocated when SwiftUI re-renders. Test: open Hub, trigger settings, return to Hub -- window must still be valid. | Manual test passes; no nil-window crashes |
| W5.4 | `Edison/Core/Capture/CaptureEngine.swift` (line 335: `startEventTracking`) | Review event tracking setup/teardown for leaked global event monitors. Verify `removeMonitor` is called on all exit paths. | Code review complete; fix if needed; manual test of repeated capture cycles shows no monitor leak |

### W6: Cleanup and Commit Untracked Work

**Rationale:** `git status` shows 4 untracked paths from v1.1 development that should be committed with the branch or explicitly deferred.

**PR granularity:** 1 PR (untracked files committed).

| Step | File(s) | Action | Acceptance |
|------|---------|--------|------------|
| W6.1 | `Edison/Core/Settings/` (3 files, 172 lines total) | Review `AppSettings.swift` (90 lines), `LaunchAtLoginController.swift` (43 lines), `SettingsStore.swift` (39 lines). These are already referenced by `AppState`. Commit with basic tests if not already covered. | Files tracked in git; referenced by existing code; no orphans |
| W6.2 | `Edison/Core/Capture/ScreenshotDocument.swift` (522 lines) | Review usage. If referenced by CaptureEngine or EditorWindowView, commit. If experimental, move to a feature branch. | Clear disposition: committed or branched |
| W6.3 | `Edison/Core/Models/CodableColor.swift` (44 lines) | Review usage. Likely used by ScreenshotDocument or editor. Commit if referenced. | Clear disposition |
| W6.4 | `Edison/Core/Shortcuts/ShortcutValidator.swift` (65 lines) | Already tested (`testShortcutValidatorReportsConflicts` in EdisonTests). Commit. | File tracked in git |

### W7: Release Prep

**PR granularity:** 1 PR (version bump, changelog, baselines update).

| Step | File(s) | Action | Acceptance |
|------|---------|--------|------------|
| W7.1 | `docs/performance-baselines.md` | Update with post-refactor measurements. Compare against W1 baselines. Document delta. Use same measurement protocol as W1.5 (3 warm-state trials, discard first, report median, same hardware). | File updated with before/after numbers |
| W7.2 | Version bump | Bump to 1.5 in project settings | `xcodebuild` produces 1.5 build |
| W7.3 | `docs/CHANGELOG.md` (or equivalent) | Document: AppState decomposition, HubView decomposition, test expansion, performance baselines, stability audit findings | Changelog entry for v1.5 |
| W7.4 | Manual QA checklist | Execute full checklist: paste-back (text, image, file URL), capture (area, window, full screen, previous area), search (empty, partial, type filter, collection filter), editor (open, annotate, undo, redo, save, discard), settings (change and verify persistence), keyboard navigation (hub shelf/list/grid), Quick Look, collections CRUD, launch-at-login toggle, 10k-item scroll performance | All items pass |
| W7.5 | CI update | Ensure the `xcode-test` workflow job builds Release with `GCC_TREAT_WARNINGS_AS_ERRORS=YES` (enforcing AC10). Confirm the `build-and-test` SPM job runs `swift test` on the split test files. If CI update is out of scope for this release, move W7.5 to an explicit follow-up ticket documented in the ADR. | CI enforces warnings-as-errors in Release, or follow-up ticket created |

---

## 6. PR/Commit Granularity Summary

| Workstream | PRs | Notes |
|------------|-----|-------|
| W1 | 1 | Instrumentation + baselines doc |
| W2 | 2 | One per coordinator: ClipboardCoordinator, then CaptureCoordinator |
| W3 | 2 | Headers + support views first; shelf/list views second |
| W4a | 1 | Test file split + new tests on current code |
| W4b | -- | Folds into W2 PRs (tests land with the extracted type) |
| W5 | 1 | Audit fixes + comments |
| W6 | 1 | Untracked files committed |
| W7 | 1 | Version bump, changelog, baselines update |
| **Total** | **9** | |

---

## 7. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **Behavior regression from AppState decomposition** | Medium | High | W4a (lifecycle tests + paste-back tests) lands BEFORE W2 begins. Run full test suite after each extraction. Manual smoke after each PR. |
| **SwiftUI redraw regression from HubView extraction** | Medium | Medium | W1.5 (baseline measurement) provides "before" data. After W3, re-run Instruments to compare body evaluation counts. If body evals increase, revert and investigate. |
| **Scope creep into features** | Low | High | Explicit gate: every PR description must state "v1.5: no new features". Reviewer (you) enforces. |
| **Paste-back timing flakiness in tests** | Medium | Low | Tests use real clock with documented tolerances (e.g., 50ms margin). Tests are marked with `@Test(.timeLimit(.minutes(1)))` to avoid CI hangs. Flaky tests are quarantined, not deleted. |
| **Untracked files have undiscovered dependencies** | Low | Low | W6 reviews each file's import graph before committing. `xcodebuild` must succeed after each commit. |
| **Performance baselines become stale** | Low | Medium | Baselines are tied to specific commit hashes. W7.1 re-measures after all changes. |

---

## 8. Verification Steps

### Automated
```bash
# Build (Release, zero warnings via xcconfig)
xcodebuild -scheme Edison -configuration Release build 2>&1 | grep -c "warning:"
# Must output 0

# Tests
swift test

# Line count verification
wc -l Edison/App/AppState.swift          # Target: approximately <= 500
wc -l Edison/UI/Hub/HubView.swift        # Target: <= 800
ls Edison/Tests/*.swift | wc -l          # Target: >= 6

# Untracked files (should be clean after W6)
git status --porcelain
```

### Instruments Profiling
1. Open Instruments with "os_signpost" template
2. Launch Edison with 1000+ items in history store (seeded via test harness script)
3. Record: open Hub via hotkey, type search query, switch layout modes, capture screenshot
4. Export trace; compare signpost durations against `docs/performance-baselines.md`
5. Open Allocations instrument; add 100 clipboard items; verify no unbounded growth

### Manual QA Checklist
- [ ] Paste-back: copy text in Safari, open Hub, select item, press Enter -- text pastes into Safari
- [ ] Paste-back: same flow with image item
- [ ] Paste-back: same flow with file URL item
- [ ] Capture: area screenshot -> editor opens -> annotate -> save
- [ ] Capture: window screenshot -> appears in history
- [ ] Capture: full screen -> appears in history
- [ ] Capture: previous area -> re-captures same region
- [ ] Search: type partial query, results filter live
- [ ] Search: select type filter (text/image/file), results narrow
- [ ] Search: select collection, results narrow to collection members
- [ ] Editor: open, draw, undo, redo, crop, save, discard
- [ ] Settings: change history limit, verify old items trimmed
- [ ] Settings: toggle launch-at-login, verify state persists
- [ ] Keyboard: navigate Hub in shelf mode with arrow keys
- [ ] Keyboard: navigate Hub in list mode with arrow keys
- [ ] Keyboard: navigate Hub in grid mode with arrow keys
- [ ] Quick Look: select item, press Space, preview appears
- [ ] Collections: create, add item, remove item, delete collection
- [ ] Scroll performance: 10k items, scroll through list mode without jank
- [ ] Quit during paste-back: no crash
- [ ] Repeated capture cycles (10x): use Instruments Allocations to verify `NSEvent` monitor count returns to baseline after each cycle

---

## 9. Out of Scope

The following are explicitly **not** part of v1.5:

- **Feature additions**: No new clipboard types, no new capture modes, no new UI surfaces
- **Cloud/sync**: No backend, no iCloud, no sync
- **AI/OCR**: No text recognition, no smart categorization
- **UI redesign**: No layout changes, no new themes, no visual refresh
- **Dependency additions**: No new SPM packages. Linting is enforced via `GCC_TREAT_WARNINGS_AS_ERRORS=YES` in an `.xcconfig` for the Release configuration -- no SwiftLint, no build plugins, no runtime dependencies.
- **Architecture layers**: No DI container, no TCA, no coordinator pattern, no protocol-based capture abstraction (deferred to a future release if CaptureEngine testability becomes a priority)
- **CaptureEngine refactor**: The 662-line file is functional and has no reported bugs. Protocol extraction (Option B) is deferred.

---

## 10. ADR: Edison v1.5 Approach

| Field | Value |
|-------|-------|
| **Decision** | Option A: Targeted Hardening -- decompose AppState (extract `ClipboardCoordinator` and `CaptureCoordinator`; paste-back methods stay in AppState), split HubView, expand tests, establish performance baselines, audit stability edges. AppState target: approximately <= 500 lines. |
| **Drivers** | (1) Stability: crash-free sessions, observer lifecycle correctness. (2) Responsiveness: measured baselines prevent silent regressions (20% regression threshold). (3) Maintainability: files under ~500/800 lines, 6+ test files, coverage for paste-back/WindowRouter/lifecycle. |
| **Alternatives considered** | Option B (broader refactor including CaptureEngine protocol extraction): rejected because it adds an abstraction layer without clear current need, increasing effort by 40-75% for speculative future benefit. Option C (tests + profiling only): rejected because it does not address the 838/1636-line maintenance debt that motivates the release. |
| **Why chosen** | Option A delivers the highest impact-to-effort ratio. It addresses the two files that account for the most maintenance friction (AppState, HubView) while respecting the project constraint of "no new architecture layers without clear need." Each workstream is independently mergeable, reducing risk. |
| **Consequences** | CaptureEngine remains a 662-line file without protocol abstraction. If capture testability becomes a priority in v1.6+, that work will require a separate decomposition effort. The Settings subsystem (172 lines across 3 files) gets committed as-is without further refactoring. AppState retains paste-back orchestration methods (~40 lines) -- this is intentional, not debt. The existing `PasteBackCoordinator` (139 lines) already handles the orchestration logic; the AppState methods are thin wrappers that delegate to it, and extracting them into a separate type would add indirection without reducing complexity. |
| **Follow-ups** | (1) Evaluate CaptureEngine protocol extraction for v1.6 if capture bugs emerge. (2) Consider SwiftUI `@Observable` migration when minimum deployment target moves to macOS 17+. (3) Re-evaluate HubView further if p95 measurements show view-body over-evaluation. (4) W7.5 CI update if deferred from this release. |

---

## 11. Workstream Dependencies and Ordering

```
W4a (Test foundation)  ──> W2 (AppState decomp)  ──> W4b (Coordinator tests)
                                    │                        │
W1 (Instrumentation)  ──> W2       ├──> W5 (Stability audit)
         │                          │
         ├──────────────────> W3 (HubView decomp)
         │
         ├──> W6 (Cleanup untracked) [can run in parallel with W2/W3]
         │
         └──────────────────────────────────────────> W7 (Release prep) [after all others]
```

**Critical path:** W1 + W4a (parallel) -> W2 -> W4b -> W5 -> W7
**Parallel track:** W3 (after W1), W6 (after W1)

W4a (test file split + golden tests on current monolith) runs before W2 begins. W4b (coordinator unit tests) follows W2, landing in the same PRs as the extracted types.

---

## 12. Effort Estimate

| Workstream | Estimated Sessions | Complexity |
|------------|-------------------|------------|
| W1: Instrumentation | 0.5 | LOW |
| W2: AppState decomposition | 1.5 | MEDIUM |
| W3: HubView decomposition | 1.0 | MEDIUM |
| W4a: Test foundation | 0.5 | LOW |
| W4b: Coordinator tests | 0.5 | LOW |
| W5: Stability audit | 0.5 | LOW |
| W6: Cleanup untracked | 0.5 | LOW |
| W7: Release prep | 0.5 | LOW |
| **Total** | **5.5 sessions** | **MEDIUM** |

One "session" = a focused 2-3 hour work block. Total: roughly 11-16 hours of focused work.

---

## 13. Changelog (Plan Revisions)

### Revision 2 (2026-04-18) -- Architect ITERATE + Critic ITERATE

**Architect feedback applied:**

- **A1:** Removed W2.3 (`PasteBackOrchestrator` extraction). Paste-back methods remain in AppState with `// MARK: - Paste Back` section. The existing `PasteBackCoordinator` at 139 lines already handles orchestration; the AppState methods are thin wrappers. AC1 updated to drop `PasteBackOrchestrator`. AppState line target revised from <= 400 to approximately <= 500.
- **A2:** Split W4 into W4a (runs before W2: test file split, PasteBackCoordinator timing tests, AppState lifecycle tests) and W4b (runs after W2: ClipboardCoordinator and CaptureCoordinator unit tests). Dependency graph updated to show W4a -> W2 -> W4b.
- **A3:** Documented `suppressedClipboardPayloads` ownership: lives in `ClipboardCoordinator`. `CaptureCoordinator` receives an injected `suppressClipboardPayload` closure at init. `writeItemToClipboard` moves to `ClipboardCoordinator`; `writeImageDataToClipboard` stays in `CaptureCoordinator`. Added to W2.1 and W2.2.
- **A4:** Moved `HubClipboardTextView` from W3.1 (shelf) to W3.4 (`HubSupportViews.swift`) since it is used by both `HubShelfCardView` and `HubListRowView`.
- **A5:** Replaced SwiftLint with `GCC_TREAT_WARNINGS_AS_ERRORS=YES` in `.xcconfig` for Release. No SPM dependency. AC10 updated. Section 9 (Out of Scope) updated.
- **A6:** Fixed factual counts: HubView has 9 @State + 1 @FocusState (not 42), 16 private structs/enums (not 30+). AppState has 18 @Published (not 13), ~40 methods (not 50+). Option C invalidation text corrected.

**Critic feedback applied:**

- **C1:** Added measurement protocol to W1.5: 3 warm-state trials, discard first, report median. Warm state defined. Same-hardware requirement documented.
- **C2:** AC7 now specifies: p95 hub open time, search filter time, and history load time must not exceed W1.5 baseline median by more than 20%. If exceeded, investigate and fix or document.
- **C3:** Added Section 4 (Golden Tests Definition) explaining what golden tests are and how P3 is verified.
- **C4:** Added PR/commit granularity per workstream (Section 6) and inline notes on each workstream.
- **C5:** AC13 sign-off changed to: "QA checklist executed and initialed by the author in the PR description for W7."
- **C6:** Added W7.5 (CI update) to ensure warnings-as-errors is enforced in CI. If out of scope, deferred to ADR follow-up.
- **C7:** Added note to W4a.1 about dual test framework structure (`#if canImport(Testing)` + `#if canImport(XCTest)`). Preserving both is the low-risk default.
- **C8:** Changed event monitor QA item from "no leaked event monitors" to "use Instruments Allocations to verify `NSEvent` monitor count returns to baseline after each cycle."
