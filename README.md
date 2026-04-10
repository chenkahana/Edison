# Edison

Edison is a native macOS menu bar app for clipboard history and screenshots.

## Current status

- Menu bar shell with a floating Hub window and configurable global shortcuts
- Clipboard history with search, favorites, type filtering, collections, export, and share actions
- Shelf-style and grid Hub layouts with keyboard navigation and a detail pane
- Screenshot capture flows for area, window, and full-screen capture
- Screenshot editor tools for crop, arrow, rectangle, text, undo/redo, copy, and save
- Status bar access for hub, screenshot capture, settings, and quit actions
- Local Swift build/test support and a macOS CI workflow

## Project docs

Use these docs for product and implementation context:

- `docs/product.md` — product definition, users, core flows, non-goals
- `docs/ui-style-guide.md` — visual system, interaction spec, and glass UI guidance
- `docs/plan.md` — phased roadmap and MVP scope
- `docs/constraints.md` — hard constraints and boundaries
- `docs/architecture.md` — architectural direction and simplicity rules
- `docs/current-task.md` — Edison 1.1 release and App Store review task
- `docs/review-checklist.md` — pre-merge checklist
- `docs/working-agreement.md` — implementation operating rules
- `docs/app-store-release-1.1.md` — App Store review notes, release text, and recording checklist

## Project layout

- `Edison/App` — app entry point and lifecycle shell
- `Edison/Core` — core domain modules (models, persistence, capture, shortcuts)
- `Edison/UI` — SwiftUI screens/components
- `Edison/Tests` — package tests
- `.github/workflows/ci.yml` — macOS CI build + test

## Run locally

- Full app flow in Xcode:

```bash
open Edison.xcodeproj
```

- Package-based launch:

```bash
swift run Edison
```

## Local CI check (macOS)

```bash
./scripts/ci-local-macos.sh
```

## Default shortcuts

- `Shift-Command-V` — open or close the Edison hub
- `Shift-Command-2` — capture area
- `Shift-Command-3` — capture window
- `Shift-Command-4` — capture full screen

## Notes

- The first run may require Accessibility and Screen Recording permissions for shortcuts and capture flows.
- Screenshot capture is available from both the global shortcuts and the status bar menu.
