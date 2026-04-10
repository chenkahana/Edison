<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# Tests

## Purpose
Unit test suite for the Edison app. Tests use the Swift Testing framework (`@Test`, `#expect`) with an XCTest fallback for compatibility. Current coverage targets `HistorySearchEngine` filtering logic, `ClipboardMonitor` pasteboard-type filtering, and `ClipboardItem` Codable round-trips.

## Key Files

| File | Description |
|------|-------------|
| `EdisonTests.swift` | All unit tests — search filtering, type filters, transient/concealed pasteboard skipping, Codable round-trip for `ClipboardItem` with source application |

## For AI Agents

### Working In This Directory
- Run tests with `swift test` from the repo root.
- Use `@Test("description")` / `#expect(...)` for new tests (Swift Testing style).
- Add XCTest equivalents below the `#elseif canImport(XCTest)` block for backward compat.
- Test only `Core/` logic — UI and AppKit-dependent classes are not unit-testable without a running app.
- Do not add test helpers or fixtures files unless multiple tests need them.

### Testing Requirements
- Each new `Core/` type should have at least a smoke test covering its primary behavior.
- `HistoryStore`, `HotKeyCenter`, and `CaptureEngine` require a running macOS process — use manual testing for these.

### Common Patterns
- Tests import `@testable import Edison` to access internal types.
- `ClipboardMonitor` exposes `shouldSkipStorage(for:)` as `internal` specifically to enable testing.

## Dependencies

### Internal
- `Core/Models/` — `ClipboardItem`, `ClipboardImageData`, `ClipboardSourceApplication`
- `Core/Search/` — `HistorySearchEngine`, `HistoryItemTypeFilter`
- `Core/Clipboard/` — `ClipboardMonitor`

### External
- `Testing` (Swift Testing framework, macOS 15+)
- `XCTest` (fallback)
- `Foundation`, `AppKit`

<!-- MANUAL: -->
