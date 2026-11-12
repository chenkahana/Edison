# Changelog

## 2.1 — unreleased

### Capture fixes
- The Hub (⇧⌘V) and the screenshot editor always open. They were SwiftUI scenes that macOS sometimes never created at launch, leaving nothing to show.
- "Copy + Open Editor" copies the capture to the clipboard (and history) immediately.
- Area and window selection now work on every display, including ones left of or above the main display.
- Area captures now grab exactly the selected region, which used to be mirrored vertically.

### Screenshot editor
- New tools: line, ellipse, freehand pen, highlighter, numbered step counter, and pixelate (replaces the soft blur, which could leak text).
- Icon toolbar with single-key tool shortcuts (V A L R O P H T N B C), Shift to snap lines to 45° and draw squares/circles, arrow-key nudge, ⌘D duplicate, ⌘[ / ⌘] size, ⌘↩ copy and close.
- One renderer draws both the canvas and the exported PNG, so arrowheads, pixelation, text, and the legibility halo look identical before and after export.
- Always-visible colour and size bar; the last-used style is remembered.
- Text is typed in place and can be re-edited; crop previews with a dimmed mask instead of zooming mid-drag, and can be reset.
- Drag the finished image straight from the editor into any app.
- Fix: crops and Retina exports now use correct pixel coordinates and keep their point size.

### Hub
- Cards show what an item is — link (site and path), colour (live swatch), code (monospaced), text, image (pixel size), file (Finder icon and folder) — with source app and favourite in a tinted header.
- Hold ⌘ to reveal ⌘1–⌘9 quick-paste badges.
- Search with `app:` and `type:` tokens; every word must match. New Links, Files, and Colours type filters.
- Annotate any history image (⌘E or context menu) without overwriting the original; ⌘O opens links and reveals files.
- Pause / resume clipboard history from the menu bar, a bindable shortcut, or the Hub; the menu-bar icon dims while paused and nothing copied in the meantime is captured on resume.
- Thumbnails are decoded once and cached instead of on every redraw.

### Open source
- Relicensed under the Mozilla Public License 2.0.
- New README, source tour, architecture and privacy docs; contributing, security, support, code-of-conduct and
  third-party notices; issue and pull-request templates and CODEOWNERS.
- Quick Look previews and drag-out images now live in an owner-only temporary folder that is cleared when they close
  and at launch, so deleted items don't linger on disk.
- CI runs with read-only permissions, a pinned checkout action and no persisted credentials; Dependabot tracks
  Actions.
- Internal planning notes and per-folder agent files are no longer published; an unused build-settings file is no
  longer copied into the app bundle.

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

Release hardening: images moved out of the history file into an image store, structured logging, visible capture and permission errors, and repository governance (#22).

## 1.0

Initial release.
