# Current Task

## Goal
Create the Edison macOS app foundation and provide a working menu bar shell with reliable Hub navigation.

## Scope
- Keep a clean Swift Package layout for app, core, UI, and tests
- Ensure there is a base app shell entry point for startup
- Ensure local macOS build/test commands are documented and scriptable
- Add and maintain a minimal GitHub Actions CI workflow for build and test on macOS
- Provide a responsive status bar menu with Open Hub, Capture, Settings, and Quit actions
- Ensure the Hub can open reliably from the menu bar shell

## Constraints
- Keep structure minimal and practical for follow-on work
- Avoid introducing unnecessary dependencies
- Keep the shell lightweight while follow-on feature work lands on top of it

## Acceptance Criteria
- App builds successfully locally on macOS
- App launches without crashing
- CI passes build checks
- Menu is responsive
- Hub opens reliably

## Status
- Completed
