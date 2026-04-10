<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# scripts

## Purpose
Shell scripts for local development and CI workflows.

## Key Files

| File | Description |
|------|-------------|
| `ci-local-macos.sh` | Runs the full CI pipeline locally on macOS — builds the project and executes the test suite |

## For AI Agents

### Working In This Directory
- Run `bash scripts/ci-local-macos.sh` from the repo root to validate a build before pushing.
- Keep scripts idempotent and side-effect-free beyond build artifacts.

### Common Patterns
- Scripts use `set -euo pipefail` style error handling.

<!-- MANUAL: -->
