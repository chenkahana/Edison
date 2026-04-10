<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# Search

## Purpose
Filtering and search over clipboard history. `HistorySearchEngine` is a stateless struct that takes an array of `ClipboardItem` values plus a query string and type filter, and returns the matching subset. It is called synchronously on the main thread as a computed property in `AppState`.

## Key Files

| File | Description |
|------|-------------|
| `HistorySearchEngine.swift` | `filter(query:in:type:)` — trims query, applies `HistoryItemTypeFilter` (.all/.text/.image), then case-insensitively matches text content, file names, or the keyword "image screenshot" for image payloads. Also defines `HistoryItemTypeFilter` enum. |

## For AI Agents

### Working In This Directory
- The engine is a value-type struct with no state — safe to call from any context.
- Image items match the literal string `"image screenshot"` — this is intentional so users can find screenshots by typing "image" or "screenshot".
- File URL items match on `url.lastPathComponent` only, not the full path.
- `HistoryItemTypeFilter` has no `.fileURL` case — file URLs fall under `.all` and are not separately filterable. Add a case here if that changes.

### Testing Requirements
- Fully unit-testable — covered by `Tests/EdisonTests.swift` (text filter, filename match, type filter, composed query+type).
- Add a test for any new filter behavior before shipping.

### Common Patterns
- Called from `AppState.filteredItems` computed property; results are then further filtered by active collection if one is selected.

## Dependencies

### Internal
- `Core/Models/` — `ClipboardItem`, `ClipboardPayload`

### External
- `Foundation`

<!-- MANUAL: -->
