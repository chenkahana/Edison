<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# Capture

## Purpose
Screen capture orchestration. `CaptureEngine` drives three capture modes (area selection, window pick, full screen) by shelling out to `/usr/sbin/screencapture`. Area selection uses a custom full-screen overlay (`RegionSelectionSession`) to let the user drag a rectangle before invoking screencapture with `-R`. Captured PNG data is broadcast via `Notification.Name.edisonScreenshotCaptured` and consumed by `AppState`.

## Key Files

| File | Description |
|------|-------------|
| `CaptureEngine.swift` | Public API: `captureArea()`, `captureWindow()`, `captureFullScreen()`. Internally manages `RegionSelectionSession` for area mode and runs screencapture as a `Process`. Also contains private `RegionSelectionSession` (overlay window + event monitor) and `SelectionOverlayView` (drag-to-select NSView). |

## For AI Agents

### Working In This Directory
- **Planned migration:** the architecture doc specifies ScreenCaptureKit as the final native capture path. The current `screencapture` CLI approach is a temporary fallback. New capture work should target ScreenCaptureKit.
- Captured images land in `FileManager.default.temporaryDirectory` as `edison-screenshot-<UUID>.png` and are deleted immediately after reading.
- `runScreencapture` spawns a `Process` on a background thread (`terminationHandler` fires on a non-main queue) — the notification dispatch back to main is explicit (`DispatchQueue.main.async`).
- `RegionSelectionSession` is `@MainActor` and creates one `NSWindow` per screen (so it covers multi-monitor setups). It uses a local event monitor to intercept mouse and keyboard events — always remove monitors in `finish(with:)`.
- Escape key (keyCode 53) cancels the region selection.
- `CaptureEngine.imageDataUserInfoKey` (`"imageData"`) is the key for the notification's `userInfo` dictionary.

### Testing Requirements
- Not unit-testable without a running macOS session with Screen Recording permission.
- Test manually via the menu-bar "Capture" item and the three global hotkeys.

### Common Patterns
- `captureArea()` is the only method that requires `@MainActor` (because it creates `RegionSelectionSession`); the others dispatch internally.

## Dependencies

### Internal
- Posts `Notification.Name.edisonScreenshotCaptured` (defined in `App/AppState.swift`)

### External
- `AppKit` (`NSWindow`, `NSView`, `NSScreen`, `NSEvent`, `NSBezierPath`)
- `Foundation` (`Process`, `FileManager`)

<!-- MANUAL: -->
