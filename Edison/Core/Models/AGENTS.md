<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-10 | Updated: 2026-04-10 -->

# Models

## Purpose
Shared value types used throughout the app. These are pure Swift structs and enums with no AppKit or SwiftUI imports — they serve as the data contract between Core services, persistence, and the UI layer.

## Key Files

| File | Description |
|------|-------------|
| `ClipboardItem.swift` | Core clipboard entry — `ClipboardItem` (id, createdAt, isFavorite, sourceApplication, payload), `ClipboardPayload` enum (.text, .image, .fileURL), `ClipboardImageData` (full PNG + thumbnail PNG), `ClipboardSourceApplication` (bundleIdentifier + name) |
| `Collection.swift` | `ItemCollection` — a user-named ordered group of `ClipboardItem` IDs; stored alongside history |

## For AI Agents

### Working In This Directory
- All types must conform to `Codable`, `Identifiable`, and `Hashable`.
- `ClipboardPayload` is a `Codable` enum with associated values — take care when adding cases, as it must remain backward-compatible with persisted JSON.
- `ClipboardImageData` stores **both** a full-resolution PNG (≤2200px) and a thumbnail PNG (≤200px) — always populate both fields.
- Do not import `AppKit` or `SwiftUI` here; keep models framework-agnostic.

### Common Patterns
- All `init` parameters have defaults for `id` (`UUID()`), `createdAt` (`.now`), and `isFavorite` (`false`) so callers only need to supply `payload`.
- `ClipboardPayload` equality and hashing are used for deduplication in `AppState.addToHistory()` and `suppressedClipboardPayloads`.

## Dependencies

### External
- `Foundation` only

<!-- MANUAL: -->
