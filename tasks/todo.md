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
- [ ] Implement the lossless representation model, persistence, capture, and paste paths.
- [ ] Implement the explicit plain-text paste action after the model path works.

## LLM judgment steps

- [x] Keep the 2.0 critical path centered on fidelity before organization and power workflows.
- [x] Limit fixture tooling to type identifiers, byte counts, and SHA-256 hashes.
- [ ] Decide payload budgets, RTFD scope, and source metadata handling from measured fixtures.
- [ ] Review the implementation for migration safety, representation ordering, and graceful fallback.

## Verification commands

```sh
git diff --check
swift scripts/inspect-pasteboard.swift --help
swift scripts/inspect-pasteboard.swift \
  --label <synthetic-fixture-label> \
  --source <source-application> \
  --output <fixture.json>
```

## Done criteria

- [ ] Real-app fixtures cover the minimum compatibility matrix without storing raw clipboard bytes.
- [ ] Existing plain-text history remains decodable.
- [ ] Supported rich representations round-trip without parsing or reserialization.
- [ ] Normal paste restores preserved representations in source order.
- [ ] Plain-text paste writes only the exact canonical plain string.
- [ ] Existing affected code paths, fixtures, assertions, and snapshots are reviewed for regressions.

## Review

Files in this foundation slice:

- `docs/edison-2.0-plan.md`
- `docs/pasteboard-fixture-workflow.md`
- `scripts/inspect-pasteboard.swift`
- `tasks/todo.md`

Verification: `git diff --check` passes. Inspector privacy was reviewed statically: fixture output
contains metadata and hashes, not pasteboard payloads. No tests were added or run; this slice is
planning, documentation, and diagnostic tooling only. Real-application fixture capture remains
blocked because Computer Use lacks the required macOS Accessibility/Automation permission.
