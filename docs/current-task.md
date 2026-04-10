# Current Task

## Goal
Prepare Edison 1.1 for release and App Store review.

## Scope
- Finalize release metadata and generated `Info.plist` values
- Remove shipping placeholders from the app surface
- Make screenshot capture fully accessible from the menu bar
- Prepare reusable App Review notes and release copy for App Store Connect
- Refresh docs so the repository reflects the real product, not just the foundation shell

## Constraints
- Keep the project dependency-free
- Do not add undocumented or unused privacy keys
- Keep the current PR branch as the release branch for this pass

## Acceptance Criteria
- App reports version `1.1 (2)` in build metadata
- App category resolves to `public.app-category.productivity`
- Status bar exposes working commands for area, window, and full-screen capture
- Settings show real About metadata with no placeholder copy
- App Review notes can be pasted into App Store Connect with minimal edits
- App builds successfully locally on macOS
- CI passes build checks

## Status
- Completed
