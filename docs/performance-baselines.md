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

> **Methodology reminder:** Follow the same protocol as the baseline above — 3 warm-state trials, discard first, report median. Same physical hardware as the baseline run. Release build, Instruments attached, no other high-CPU processes.
>
> **Fill in during manual QA before tagging v1.5.**

Date: TBD
Commit: `40d856e12411f6ec666f7f61b0b09e56d0a7ffe5` (post-W5 HEAD; update to `<v1.5 release SHA>` when tag is cut)
Delta: (target ≤ +20% on p95 medians)

| Metric | p50 | p95 | Delta vs baseline p95 | Pass? |
|--------|-----|-----|-----------------------|-------|
| Hub toggle (shortcut → window visible) | TBD | TBD | TBD | TBD |
| History load (cold launch → items ready) | TBD | TBD | TBD | TBD |
| Search filter (keystroke → rendered results) | TBD | TBD | TBD | TBD |
| Capture start-to-result (area screenshot) | TBD | TBD | TBD | TBD |

### AC7 Verification Checklist

Before tagging v1.5, confirm each item:

- [ ] p95 hub open time ≤ baseline p95 median × 1.20
- [ ] p95 search filter time ≤ baseline p95 median × 1.20
- [ ] p95 history load time ≤ baseline p95 median × 1.20
- [ ] If any threshold is exceeded: root cause investigated and either fixed or documented with a justification note in this file.

Threshold: post-refactor p95 must not exceed the W1 baseline median by more than 20% (AC7).
