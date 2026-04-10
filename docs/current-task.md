# Current Task

## Goal
Create the Edison macOS app foundation so the project builds, launches, and has a minimal CI path.

## Scope
- Keep a clean Swift Package layout for app, core, UI, and tests
- Ensure there is a base app shell entry point for startup
- Ensure local macOS build/test commands are documented and scriptable
- Add/maintain a minimal GitHub Actions CI workflow for build + test on macOS
- Do not introduce feature logic in this task

## Constraints
- No screenshot or clipboard feature work
- No additional dependencies unless required for startup/build
- Keep structure minimal and practical for follow-on work

## Acceptance Criteria
- App builds successfully locally on macOS
- App launches without crashing
- CI passes build checks
- Project structure is clean enough for follow-on feature work

## Status
- Completed
