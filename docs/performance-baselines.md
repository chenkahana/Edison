# Edison Performance Baselines

Baselines captured before v1.5 refactor work. Used as the reference point for AC7:
"Post-refactor p95 must not exceed baseline median by more than 20%."

## Measurement Protocol

- **Trials:** 3 warm-state trials per measurement; discard first, report median.
- **Warm state:** App open ≥ 5s with 1000 items loaded.
- **Seeding:** History seeded via test harness script (TBD — see W1 follow-up).
- **Hardware:** Measurements taken on the same physical hardware as the comparison run.
- **Instrument template:** os_signpost
- **Environment:** Release build, Instruments attached, no other high-CPU processes.

## Baseline — commit `<FILL IN>` (W1 snapshot)

Date: <FILL IN>
Hardware: <FILL IN — e.g., MacBook Pro M3 Pro, 36 GB>
macOS: <FILL IN>
Build: Release

| Metric | p50 | p95 | Notes |
|--------|-----|-----|-------|
| Hub toggle (shortcut → window visible) | TBD | TBD | |
| History load (cold launch → items ready) | TBD | TBD | |
| Search filter (keystroke → rendered results) | TBD | TBD | |
| Capture start-to-result (area screenshot) | TBD | TBD | |

## Memory baseline

| Metric | Value | Notes |
|--------|-------|-------|
| RSS after 1000 items added | TBD | Instruments Allocations |
| Growth after 10k additions | TBD | Should be O(1) per item |

## Post-refactor comparison (to be filled during W7)

Date: TBD
Commit: TBD
Delta: (target ≤ +20% on p95 medians)
