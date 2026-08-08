# Current Task

## Goal
Plan Edison 2.0 around trustworthy text fidelity, an explicit plain-text paste workflow, and
competitive improvements that preserve Edison's focused shelf experience.

## Scope
- Diagnose the formatting-loss mechanism in the current clipboard pipeline
- Define lossless rich-text capture, persistence, migration, and paste behavior
- Specify “Paste as Plain Text” context-menu and keyboard behavior
- Review leading clipboard-manager patterns for retrieval, organization, and privacy
- Sequence the work into testable milestones with acceptance criteria

## Constraints
- Keep the project dependency-free
- Preserve compatibility with Edison 1.1 history
- Default paste must never transform or normalize user content
- Keep clipboard data local for 2.0
- Validate competitive claims against current first-party sources before using them externally

## Acceptance Criteria
- Root cause and affected code paths are documented
- Normal paste and plain-text paste have distinct, testable semantics
- Persistence and migration risks are addressed
- Cross-application and automated test matrices are defined
- Improvements are prioritized into P0, P1, and later opportunities
- Open product/technical decisions are explicit

## Status
- Completed

## Deliverable
- [`docs/edison-2.0-plan.md`](edison-2.0-plan.md)
