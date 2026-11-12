# Contributing to Edison

Thanks for helping make Edison better. This guide covers how to report problems, propose changes and get a pull
request merged.

## Before you start

- **Bugs and ideas** go in [GitHub Issues](https://github.com/chenkahana/Edison/issues/new/choose). Search first; add
  to an existing issue rather than opening a duplicate.
- **Security issues** must not be filed publicly. Follow [SECURITY.md](SECURITY.md).
- **Larger changes** (new features, new dependencies, persistence or pasteboard changes) need an issue agreed with a
  maintainer before you write the code.

By opening a pull request you confirm that you wrote the change, or have the right to submit it, and you agree that
it is licensed under the [Mozilla Public License 2.0](LICENSE), the same license as the rest of Edison.

## Development setup

```bash
open Edison.xcodeproj
```

Requirements and permissions are in the [README](README.md#getting-started); a tour of the source is in
[Edison/README.md](Edison/README.md). The Xcode project uses synchronized folders: add Swift files under `Edison/`
and they are compiled by both Xcode and `swift build` without editing the project.

## Branches and commits

- `main` is always releasable. Work on a branch named `<type>/<short-description>`, e.g. `fix/hub-focus`.
- Write commit subjects in the imperative mood, under 72 characters ("Fix paste-back into full-screen apps"). Explain
  *why* in the body when it isn't obvious.
- Keep a pull request to one concern. Refactors go in their own pull request.
- Add follow-up commits to an open pull request instead of force-pushing; it is squashed when merged.

## Code guidelines

- **Layering.** Lifecycle and orchestration live in `Edison/App`, pure logic and services in `Edison/Core` (no
  SwiftUI imports), and views in `Edison/UI`. Views read from and dispatch to `AppState`; they hold no business
  logic.
- **Main actor for UI.** Mark anything that touches AppKit, SwiftUI or `@Published` state `@MainActor`. Disk and
  pasteboard processing runs on serial background queues and must never block the main thread.
- **Clipboard fidelity is a feature.** Never trim, normalize, re-wrap or re-encode stored text. Display-only
  transformations stay in the UI layer. Changes to capture or paste-back need tests.
- **Design tokens.** Colours, spacing and radii come from `HubTheme`; follow the
  [UI style guide](docs/ui-style-guide.md).
- **Privacy.** No analytics, tracking, network calls or third-party SDKs. Never log clipboard or screenshot content;
  use `Log` (OSLog) for diagnostics, not `print`. Anything new that is stored must be deleted with its item and
  described in [docs/privacy.md](docs/privacy.md).
- **Accessibility.** Every control needs a VoiceOver label, keyboard access where it makes sense, and must respect
  Reduce Transparency and Reduce Motion.
- **Comments** explain intent and constraints, not what the next line does.

## Checks before you open a pull request

```bash
swift build && swift test
```

- Build the Release configuration in Xcode (or run `./scripts/ci-local-macos.sh`); Release builds treat warnings
  as errors.
- Run the app and exercise what you changed: the Hub (shelf, list and grid), paste-back into another app, and the
  editor if you touched capture or annotation.
- Fill in the pull request template, including screenshots or a recording for UI changes.

CI builds Debug and Release, runs the tests and produces an unsigned archive on every pull request; it must pass
before review.

## Code of conduct

Everyone taking part is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
