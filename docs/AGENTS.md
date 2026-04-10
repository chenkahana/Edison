<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# docs

## Purpose
Design and planning documents for the Edison project. These are human- and AI-readable references that define product direction, architectural decisions, UI conventions, and working agreements. They do not affect the build.

## Key Files

| File | Description |
|------|-------------|
| `architecture.md` | Architectural direction: app structure, SwiftUI vs AppKit split, persistence strategy, screenshot capture roadmap, simplicity rules |
| `product.md` | Product specification and feature goals |
| `plan.md` | Implementation plan and task breakdown |
| `current-task.md` | Active task in progress — updated frequently |
| `ui-style-guide.md` | Visual design system: spacing, colors, radii, typography, component patterns |
| `constraints.md` | Technical and product constraints to keep in mind during development |
| `review-checklist.md` | Pre-merge checklist for code reviews |
| `working-agreement.md` | Team norms and collaboration expectations |

## For AI Agents

### Working In This Directory
- Read `architecture.md` before making structural changes to the codebase.
- Read `ui-style-guide.md` before adding or modifying any SwiftUI views — all UI must conform to `HubTheme` constants.
- `current-task.md` is the authoritative statement of what is being worked on right now.
- Do not modify docs unless explicitly asked; these are source-of-truth documents.

### Common Patterns
- Decisions documented here supersede any inferred pattern from the code.
- The architecture doc explicitly states: prefer direct implementation over abstractions; add layers only when needed.

<!-- MANUAL: -->
