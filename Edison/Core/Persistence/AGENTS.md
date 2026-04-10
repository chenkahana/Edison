<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# Persistence

## Purpose
Disk persistence for clipboard history and user collections. `HistoryStore` serializes a combined snapshot of `[ClipboardItem]` + `[ItemCollection]` to a single JSON file at `~/Library/Application Support/Edison/history.json`. All I/O is non-blocking, routed through a dedicated serial queue.

## Key Files

| File | Description |
|------|-------------|
| `HistoryStore.swift` | `loadAsync(_:)` reads on background queue and calls back on main; `load()` is synchronous; `save(items:collections:)` encodes and writes atomically on background queue. Handles corrupt-file quarantine by renaming to `.corrupt.json`. |

## For AI Agents

### Working In This Directory
- Writes use `.atomic` option (`Data.write(to:options:)`) — safe against partial writes and crashes.
- `HistorySnapshot` is a private `Codable` struct wrapping both arrays; it is the on-disk format. Do not change it without a migration path.
- Backward-compat: if decoding as `HistorySnapshot` fails, it retries as a legacy `[ClipboardItem]` array (older Edison versions stored items only). Preserve this fallback.
- If the JSON is corrupt beyond the legacy fallback, the file is renamed to `history.corrupt.json` and an empty snapshot is returned — no crash.
- `ioQueue` is serial with `.utility` QoS — never dispatch UI work onto it.

### Testing Requirements
- `HistoryStore` can be tested by writing to a temp directory; pass a custom `FileManager` with a temp URL.
- Test: save → reload round-trip preserves all fields. Test: corrupt file quarantine.

### Common Patterns
- `encoder.outputFormatting = [.prettyPrinted]` — the persisted JSON is human-readable for debugging.
- Storage path: `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first` + `"Edison/history.json"`.

## Dependencies

### Internal
- `Core/Models/` — `ClipboardItem`, `ItemCollection`

### External
- `Foundation` (`JSONEncoder`, `JSONDecoder`, `DispatchQueue`, `FileManager`)

<!-- MANUAL: -->
