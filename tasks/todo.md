Spawn the following subagents:
1. `explorer` / read-only — deterministic discovery: rg/git/gh/MCP evidence, no LLM guessing.
2. `architect` / read-only — design, boundaries, risks, phase plan.
3. `worker` / danger-full-access — bounded implementation slice.
4. `reviewer` / read-only — correctness, regressions, architecture drift, missed tests.
5. `testgen` / danger-full-access — focused deterministic tests/fixtures when needed.
6. `docs` / danger-full-access — docs only after behavior works, when needed.

# Edison 2.0 deployability verification

## Deterministic steps

- [x] Map PR #25 and PR #26 ancestry, diffs, and required checks.
- [x] Reproduce PR #25's Xcode failure from its exact remote head.
- [x] Inspect release signing, archive, update, entitlement, migration, and persistence paths.
- [x] Repair PR #25 on its own branch and preserve clean stacked ancestry for PR #26.
- [x] Add focused executable coverage for rich capture/replay, plain paste, migration, and cleanup.
- [x] Run targeted tests, the full Swift suite, and Release Xcode build/archive.
- [ ] Complete the real destination-application matrix through macOS Accessibility automation.
- [ ] Push both branches and wait for every required check on both PRs.

## LLM judgment steps

- [x] Define the release/deployability boundary from repository evidence.
- [x] Choose the smallest test seams that exercise production clipboard behavior.
- [x] Review privacy, corruption fallback, startup ordering, and storage cleanup risks.
- [x] Challenge the final stack for regressions and unverified deployment assumptions.

## Verification commands

```sh
git merge-base --is-ancestor origin/chenk/v1.5 origin/codex/edison-2-fidelity-foundation
swift build
swift test
xcodebuild -project Edison.xcodeproj -scheme Edison -configuration Release \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Edison.xcodeproj -scheme Edison -configuration Release \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO archive
gh pr checks 25 --repo chenkahana/Edison
gh pr checks 26 --repo chenkahana/Edison
```

## Done criteria

- [ ] PR #25 and PR #26 retain the intended parent-child topology.
- [ ] Every required GitHub check passes on both PRs.
- [x] Rich and plain clipboard workflows have red-to-green executable coverage.
- [x] The full stacked Release app builds and archives.
- [ ] Native app E2E passes repeatedly, or deployability is not claimed.
- [x] Final review reports no release-blocking correctness, privacy, or migration findings.

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
- [x] Existing plain-text history remains decodable.
- [x] Supported rich representations round-trip without parsing or reserialization.
- [x] Normal paste restores preserved representations in source order.
- [x] Plain-text paste writes only the exact canonical plain string.
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

Verification: `git diff --check`, the inspector help smoke test, `swift build`, warning-clean Debug
and Release Xcode builds, and the unsigned 2.0 archive pass. `swift test` passes 44 tests across 10
suites on three consecutive full runs. The new integration suite covers RTF, RTFD, HTML, exact
plain text, AppKit destination negotiation, restart persistence, legacy decoding, corrupt-sidecar
fallback, cleanup, mode routing, self-write behavior, and Shift-Return routing.
Real-application fixture capture remains blocked because Computer Use lacks the required macOS
Accessibility/Automation permission.
