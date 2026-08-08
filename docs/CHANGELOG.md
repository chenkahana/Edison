# Changelog

## 2.0 — 2026-08-08

### Clipboard fidelity

- Preserve ordered plain-text, RTF, RTFD, and HTML pasteboard representations without parsing or reserialization.
- Restore captured source formatting by default and fall back safely to the exact canonical plain string when rich sidecars are unavailable or corrupt.
- Add **Paste as Plain Text** to item context menus and Shift-Return/Shift-keypad-Enter handling.
- Keep representation sidecars bounded, integrity-checked, reconciled at startup, and deleted with their history items.

### Verification and release hardening

- Add isolated AppKit integration coverage for capture, rich/plain replay, destination negotiation, restart persistence, legacy history migration, corruption fallback, cleanup, mode routing, and self-write suppression.
- Set the application marketing version to 2.0 and enforce warning-free Release builds.
- Extend CI to build Debug and Release configurations and produce a validated unsigned macOS archive.

## 1.5 — 2026-04-18

### Stability & Performance
- Decompose `AppState` into focused coordinators: `ClipboardCoordinator` (history mutation, clipboard writes, `suppressedClipboardPayloads`) and `CaptureCoordinator` (screenshot session lifecycle). AppState now orchestrates, not implements. Public API preserved; no view changes required.
- Decompose `HubView.swift` (1636 → 665 lines) into `HubHeaderView`, `HubShelfView`, `HubListView`, `HubSupportViews`. Shelf and list share `HubClipboardTextView` via the support file.
- Add `os_signpost` intervals for Hub toggle, search filter, history load, and capture. Enables performance regression detection in Instruments.
- Fix potential observer leak at `AppState.deinit` (was async `Task { @MainActor }`; now synchronous `NotificationCenter.removeObserver`).
- Fix event monitor leak safety net in `CaptureEngine.RegionSelectionSession` deinit.

### Tests
- Split `EdisonTests.swift` (927 lines) into 9 domain files: Search, Clipboard, PasteBack, Shortcuts, Capture, Collection, AppStateLifecycle, ClipboardCoordinator, CaptureCoordinator. Shared fixtures in `TestHelpers.swift`.
- New golden tests covering the refactor surface:
  - `PasteBackCoordinator` timing: success, accessibility-denied, nil-target (3 cases)
  - `AppState` lifecycle: no-runtime-services init, deinit observer safety, settings round-trip (3 cases)
  - `WindowRouter` lifecycle: toggle, dismiss, editor open/close (4 cases)
  - `ClipboardCoordinator` in isolation: suppression, delete/undo, favorite (3 cases)
  - `CaptureCoordinator` in isolation: success, failure, commit ordering (3 cases)
- Test count: 20 → 36. Dual Swift Testing + XCTest framework support preserved.

### Tooling
- Add `Edison/Configs/Release.xcconfig` with `GCC_TREAT_WARNINGS_AS_ERRORS=YES` and `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`. Wiring to Xcode Release configuration is a manual follow-up (see TODO in the xcconfig).

### Internal
- No user-facing feature changes. No product scope changes. No new dependencies.

### Follow-ups deferred from v1.5
- Wire `Edison/Configs/Release.xcconfig` into `Edison.xcodeproj` Release configuration.
- Evaluate `CaptureEngine` protocol extraction if capture bugs emerge (was Option B; deferred per P2 "no new abstractions without clear need").
- Consider SwiftUI `@Observable` migration when minimum deployment target moves to macOS 17+.

## 1.1 — 2026-04-11

See `docs/app-store-release-1.1.md`.

## 1.0

Initial release.
