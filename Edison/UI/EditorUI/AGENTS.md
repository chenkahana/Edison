<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# EditorUI

## Purpose
Screenshot annotation editor. `EditorWindowView` is a SwiftUI view that renders a captured image and lets the user annotate it with arrows, rectangles, and text, crop it, then copy or save the result. All drawing is done by locking focus on `NSImage` copies — no Core Graphics context management required. Undo/redo is implemented as a history stack of `NSImage` snapshots (max 50 states).

## Key Files

| File | Description |
|------|-------------|
| `EditorWindowView.swift` | Full editor view — top toolbar (tool picker, undo/redo, copy, save, done), canvas with drag gesture for drawing, text insertion popover, coordinate-space conversion between display and image pixels. Drawing primitives: `drawArrow`, `drawRectangle`, `drawText`, `crop`. |

## For AI Agents

### Working In This Directory
- All drawing mutates a copy of the current image (`image.cloned()`) and pushes the result onto the history stack via `pushHistory(_:)` — never mutate the image in place.
- Coordinate system: the image is rendered with `aspect-fit` scaling inside the canvas. Use `toImagePoint` / `toDisplayPoint` to convert between display coordinates and image-pixel coordinates. `fittedImageRect` computes the aspect-fit frame.
- The accent color for all annotations is `NSColor.systemRed` — do not introduce per-tool color pickers without a design review.
- `EditorTool` cases: `.crop`, `.arrow`, `.rectangle`, `.text`. Text tool uses a two-step flow: click sets `textInsertionPoint`, then a popover collects the string and `commitText(at:)` draws it.
- `crop` uses `cgImage(forProposedRect:)` and then `CGImage.cropping(to:)` — the crop rect must be scaled by `cgImage.width / image.size.width` to account for `@2x` backing scale.
- History is capped at 50 states; older states are dropped from the front of the array.
- `initializeImageIfNeeded(force:)` is called on `onAppear` and on `imageData` change — pass `force: true` when reloading from a new capture.

### Testing Requirements
- No automated tests. Verify each tool (arrow, rectangle, text, crop) manually.
- Verify undo/redo cycles back through states correctly.
- Verify copy and save produce valid PNG files.

### Common Patterns
- `NSImage.cloned()` and `NSImage.pngData()` are private extensions in this file — do not duplicate in other files; consider moving to a shared `NSImage` extension if needed elsewhere.
- `Comparable.clamped(to:)` is a private extension for bounding normalised coordinates to `0...1`.

## Dependencies

### Internal
- Called from `HubView` as a sheet; receives `imageData: Data?` and `onClose: () -> Void` from `AppState`.

### External
- `SwiftUI`, `AppKit`, `UniformTypeIdentifiers`

<!-- MANUAL: -->
