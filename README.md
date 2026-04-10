# Edison

Edison is a native macOS menu bar app for clipboard history and screenshots.

## Current status

This branch contains the Phase 1 shell implementation:

- Menu bar app via `NSStatusItem`
- Hub + Settings windows
- Screenshot menu actions wired to `/usr/sbin/screencapture`
- Global hotkey infrastructure with configurable shortcuts
- Core folder layout for upcoming phases

## Run

```bash
swift run Edison
```
