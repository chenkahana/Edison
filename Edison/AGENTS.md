<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# Edison (source root)

## Purpose
Contains all Swift source code for the Edison app. The directory is the SPM executable target root and is structured by domain: `App` wires together the process lifecycle, `Core` holds business logic and services, `UI` contains all SwiftUI views, `Tests` holds the test suite, and `Resources` is reserved for bundled assets.

## Key Files
_No Swift files live directly in this directory — all code is in subdirectories._

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `App/` | App entry point, lifecycle, AppDelegate, AppState, StatusBar, WindowRouter (see `App/AGENTS.md`) |
| `Core/` | Business-logic services: clipboard monitoring, capture, search, persistence, shortcuts, models (see `Core/AGENTS.md`) |
| `UI/` | SwiftUI views and themes: Hub shelf, screenshot editor, settings, shared components (see `UI/AGENTS.md`) |
| `Tests/` | Unit test suite (see `Tests/AGENTS.md`) |
| `Resources/` | Bundled resources processed by SPM (currently empty) |

## For AI Agents

### Working In This Directory
- Follow the domain split: app lifecycle → `App/`, pure logic → `Core/`, views → `UI/`.
- New files must be added to the correct subdirectory; never add Swift files directly here.
- The SPM target includes everything under `Edison/` (except `Tests/`), so any new `.swift` file is automatically compiled — no manifest changes needed unless adding resources.

### Testing Requirements
- Run `swift test` from the repo root.
- Test files belong in `Tests/`.

### Common Patterns
- Services are injected into SwiftUI views via `@EnvironmentObject var appState: AppState`.
- Use `@MainActor` for all types that touch UI or `Published` state.
- Background I/O (clipboard processing, disk writes) uses serial `DispatchQueue` with `.utility` QoS.

## Dependencies

### Internal
- All subdirectories are part of the same SPM target and can import each other freely.

<!-- MANUAL: -->
