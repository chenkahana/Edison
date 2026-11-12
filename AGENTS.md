# Agent guide for Edison

Instructions for AI coding agents (and a fast orientation for humans). The [README](README.md), the
[source tour](Edison/README.md) and [CONTRIBUTING.md](CONTRIBUTING.md) are the source of truth; this file only adds
what an agent needs to work safely.

## What Edison is

A sandboxed macOS 14+ menu-bar app: clipboard history in a keyboard-driven "Hub" shelf, plus screenshot capture and
annotation. Apple SDKs plus Sparkle (updates, Xcode project only); no network code of its own.

## Build and verify

```bash
swift build && swift test
```

- Release builds treat warnings as errors; CI also builds Debug and Release with `xcodebuild` and archives.
- The Xcode project uses synchronized folders: add files under `Edison/`, never hand-edit `project.pbxproj`.
- Non-Swift files inside `Edison/` must be excluded in `Package.swift` (`targetExcludes`).

## Where things go

- `Edison/App`: lifecycle, `AppState` (the only `ObservableObject`), windows, menu bar, paste-back.
- `Edison/Core`: services and models. **No SwiftUI imports.** Services are owned by `AppState`.
- `Edison/UI`: SwiftUI views. No business logic; read from and dispatch to `AppState`. Colours, spacing and
  radii come from `HubTheme`.
- `Edison/Tests`: Swift Testing suites; shared fixtures in `TestHelpers.swift`.

## Rules that matter

- **Clipboard fidelity.** Never trim, normalize, re-wrap or re-encode stored text. Display-only transforms stay in
  `UI`. Paste writes every preserved representation; plain paste writes only the exact string.
- **Privacy.** Never log, persist outside the stores, or transmit clipboard or screenshot content. Anything stored
  must be deleted with its item. Temporary files go through `TemporaryFiles`.
- **Main actor.** UI-touching types are `@MainActor`; disk and pasteboard work stays off the main thread.
- **Editor rendering.** Draw annotations only through `ScreenshotAnnotationRenderer` so canvas and export match.
  Annotation geometry is in image points with a bottom-left origin; `CGImage.cropping(to:)` is top-left.
- **Multi-display.** Verify real window frames against every `NSScreen`, not just computed rects.
- Keep changes small and focused; update [CHANGELOG.md](CHANGELOG.md) under "unreleased" for user-visible changes.
