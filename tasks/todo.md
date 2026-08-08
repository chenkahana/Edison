Spawn the following subagents:
1. `explorer` / read-only — deterministic discovery: rg/git/gh/MCP evidence, no LLM guessing.
2. `architect` / read-only — design, boundaries, risks, phase plan.
3. `worker` / danger-full-access — bounded implementation slice.
4. `reviewer` / read-only — correctness, regressions, architecture drift, missed tests.
5. `testgen` / danger-full-access — focused deterministic tests/fixtures when needed.
6. `docs` / danger-full-access — docs only after behavior works, when needed.

# Edison 2.0 fidelity foundation

## Deterministic steps

- [x] Recover the Edison 2.0 plan and confirm its current repository location.
- [x] Work in the dedicated `edison-2-fidelity-foundation` worktree created from a clean baseline.
- [x] Add a metadata-only pasteboard inspector and fixture-capture workflow.
- [x] Review inspector output for clipboard-content and privacy leakage.
- [x] Validate competitive capabilities against current first-party sources.
- [ ] Capture fixtures from the real source applications in the compatibility matrix.
- [x] Implement the lossless representation model, persistence, capture, and paste paths.
- [x] Implement the explicit plain-text paste action after the model path works.

## LLM judgment steps

- [x] Keep the 2.0 critical path centered on fidelity before organization and power workflows.
- [x] Limit fixture tooling to type identifiers, byte counts, and SHA-256 hashes.
- [ ] Decide payload budgets, RTFD scope, and source metadata handling from measured fixtures.
- [x] Review the implementation for migration safety, representation ordering, and graceful fallback.

## Verification commands

```sh
git diff --check
swift scripts/inspect-pasteboard.swift --help
swift scripts/inspect-pasteboard.swift \
  --label <synthetic-fixture-label> \
  --source <source-application> \
  --output <fixture.json>
swift build
swift test
xcodebuild -project Edison.xcodeproj -scheme Edison -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /Users/chenk/tmp/codex/Edison/DerivedData-edison2 \
  CODE_SIGNING_ALLOWED=NO build
```

## Done criteria

- [ ] Real-app fixtures cover the minimum compatibility matrix without storing raw clipboard bytes.
- [ ] Existing plain-text history remains decodable.
- [ ] Supported rich representations round-trip without parsing or reserialization.
- [ ] Normal paste restores preserved representations in source order.
- [ ] Plain-text paste writes only the exact canonical plain string.
- [x] Existing affected code paths, fixtures, assertions, and snapshots are reviewed for regressions.

## Review

Files in this foundation slice include:

- `docs/edison-2.0-plan.md`
- `docs/pasteboard-fixture-workflow.md`
- `scripts/inspect-pasteboard.swift`
- `Edison/Core/Models/ClipboardItem.swift`
- `Edison/Core/Persistence/ClipboardRepresentationStore.swift`
- `Edison/Core/Clipboard/ClipboardMonitor.swift`
- `Edison/Core/Clipboard/ClipboardCoordinator.swift`
- `Edison/App/PasteBackCoordinator.swift`
- `Edison/App/AppState.swift`
- `Edison/UI/Hub/HubSupportViews.swift`
- `Edison/UI/Hub/HubShelfView.swift`
- `Edison/UI/Hub/HubListView.swift`
- `Edison/UI/Hub/HubView.swift`
- `Edison/Core/Settings/LaunchAtLoginController.swift`
- `tasks/todo.md`

Verification: `git diff --check`, the inspector help smoke test, `swift build`, and the unsigned
Release `xcodebuild` pass. `swift test` passes 36 tests across 9 suites. No tests were added. Rich
capture, replay, degradation, and Shift-Return behavior still require the real-application
compatibility matrix before fidelity is considered verified.
Real-application fixture capture remains blocked because Computer Use lacks the required macOS
Accessibility/Automation permission.
