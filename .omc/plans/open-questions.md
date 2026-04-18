# Open Questions

## Edison v1.5 - 2026-04-18

- [ ] **Merge paste-back branch first?** — The current branch `chenk/paste-back-selected-item` has uncommitted/untracked work. Should this be merged to `main` before starting v1.5, or should v1.5 branch from it? Affects merge conflict risk.
- [ ] **SwiftLint: add or skip?** — AC10 requires zero compiler warnings. A lightweight SwiftLint build plugin enforces style consistency, but it is a new dependency. Alternative: use `xcodebuild` warning-as-error flags with no dependency. Which approach do you prefer?
- [ ] **CaptureEngine deinit for event monitors** — W5.4 calls for reviewing `startEventTracking` (line 335) for leaked global event monitors. If a leak is found, the fix may touch CaptureEngine more than the "keep CaptureEngine as-is" decision implies. Acceptable scope expansion if needed?
- [ ] **AppState.deinit async cleanup** — W5.1 notes that the `Task { @MainActor }` in `deinit` (lines 168-181) may not execute on process exit. If the audit determines synchronous removal is needed, it changes the deinit contract. Decision: document-only or fix?
- [ ] **10k-item test harness** — AC13 and the QA checklist call for testing with 10k clipboard items. Is there an existing test data generator, or does one need to be built as part of W1?
- [ ] **Performance baseline hardware** — Baselines are machine-specific. Should `docs/performance-baselines.md` document the hardware used, or should baselines be expressed as relative (e.g., "hub open time should not exceed 2x history load time")?
