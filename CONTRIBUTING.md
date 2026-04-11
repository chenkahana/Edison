# Contributing to Edison

Thank you for your interest in contributing!

## Branches

- `main` — stable, release-ready code
- Feature branches: `feature/<short-description>`
- Bug fixes: `fix/<short-description>`

## Pull Request Checklist

Before submitting a PR:

- [ ] `swift build` passes with no new warnings
- [ ] `swift test` passes
- [ ] Changes are minimal and focused (one concern per PR)
- [ ] New public-facing behaviour is documented in code comments
- [ ] UI changes follow the [UI Style Guide](docs/ui-style-guide.md)

## Code Style

- Follow the Swift API Design Guidelines
- Prefer value types; use classes only when identity semantics are required
- Mark `@MainActor` on any type that touches UI or AppKit APIs
- Use `OSLog`/`Logger` for diagnostics — no `print()` in production paths

## Architecture

See [docs/architecture.md](docs/architecture.md) for an overview of the component model.

## Reporting Bugs

Open a GitHub Issue with:
1. Edison version (from Help > About)
2. macOS version
3. Steps to reproduce
4. Expected vs actual behaviour
