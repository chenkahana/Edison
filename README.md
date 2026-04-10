# Edison

Edison is a native macOS menu bar app for clipboard history and screenshots.

## Project docs

Use these docs as the source of truth for implementation:

- `docs/product.md` — product definition, users, core flows, non-goals
- `docs/ui-style-guide.md` — visual system, interaction spec, and glass UI guidance
- `docs/plan.md` — phased roadmap and MVP scope
- `docs/constraints.md` — hard constraints and boundaries
- `docs/architecture.md` — architectural direction and simplicity rules
- `docs/current-task.md` — active implementation task
- `docs/review-checklist.md` — pre-merge checklist
- `docs/working-agreement.md` — implementation operating rules

## Current status

This repository contains the Edison macOS app foundation (app shell, project skeleton, and CI baseline).

## Project layout

- `Edison/App` — app entry point and lifecycle shell
- `Edison/Core` — core domain modules (models, persistence, capture, shortcuts)
- `Edison/UI` — SwiftUI screens/components
- `Edison/Tests` — package tests
- `.github/workflows/ci.yml` — macOS CI build + test


## Run

```bash
swift run Edison
```

## Local CI check (macOS)

```bash
./scripts/ci-local-macos.sh
```
