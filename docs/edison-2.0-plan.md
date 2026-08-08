# Edison 2.0 Product and Delivery Plan

## Product thesis

Edison 2.0 should make reusing anything from the clipboard feel trustworthy, fast, and
deliberate. The release should lead with **paste fidelity**: a normal paste preserves what
the source application placed on the clipboard, while an explicit plain-text action removes
formatting without changing the underlying words or whitespace.

The Hub should remain a native, keyboard-first shelf rather than becoming a general-purpose
launcher. Screenshot capture and annotation remain differentiators, but clipboard reliability
comes before adding more surface area.

## What we learned from the current implementation

The formatting bug is structural rather than cosmetic:

- `ClipboardMonitor` currently reads text with `string(forType: .string)` and creates a
  `.text(String)` payload. RTF, RTFD, HTML, tabular, and other representations supplied by the
  source application are discarded at capture time.
- `AppState` later clears the pasteboard and writes only `.string`, so the destination never
  has an original rich representation to choose from.
- The plain `String` must remain byte-for-byte equivalent at the UTF-8 boundary after a
  persistence round trip. Edison must not trim, collapse whitespace, re-wrap lines, normalize
  tabs, or synthesize spaces during capture, display, search, copy, or paste.
- Existing saved `.text` items must continue decoding and behave as plain-text-only items.

This also explains why fixing only the Hub preview would not fix pasting.

## Competitive review

This review uses public product materials as directional input, not a request to clone another
app. Network access was unavailable during this planning pass, so every market claim must be
revalidated against the linked first-party page before implementation or marketing copy is
finalized.

| Product | Directional strengths to validate | Lesson for Edison |
|---|---|---|
| [Paste](https://pasteapp.io/) | Visual, bottom-of-screen history; source-aware previews; pinboards; search; cross-device continuity | Preserve Edison's shelf identity, improve visual recognition, and make organization feel lightweight rather than file-manager-like |
| [Raycast Clipboard History](https://www.raycast.com/core-features/clipboard-history) | Keyboard-first retrieval, type/source filtering, pinned entries, privacy-oriented retention controls | Make every common action keyboard reachable and expose retention and exclusions clearly |
| [Maccy](https://maccy.app/) | Focused, fast, open-source clipboard history with search, pinning, and plain-text workflows | Reliability and speed are features; plain-text paste deserves a first-class shortcut rather than a buried preference |
| [PastePal](https://indiegoodies.com/pastepal) | Rich previews, collections, application filtering, and Apple-device integration | Improve rules and collection workflows only after the data model preserves clipboard types correctly |
| [Alfred Clipboard History](https://www.alfredapp.com/help/features/clipboard/) | Searchable history, snippets, merging, configurable retention, and ignored applications | Rules and power workflows can differentiate a later milestone, but should not block the fidelity release |

### Principles adapted for Edison

1. **Trust before breadth.** A clipboard manager that subtly changes content is worse than no
   history at all.
2. **Two explicit intents.** “Paste” preserves source representations; “Paste as Plain Text”
   writes only the exact plain string.
3. **Keyboard and pointer parity.** Context-menu actions also need discoverable shortcuts and
   VoiceOver labels.
4. **Recognition over decoration.** Source app, content type, first meaningful content, and age
   should be scannable without making cards visually noisy.
5. **Private by default.** Exclusions, retention, and deletion must be understandable and local.

## Release goals

### P0 — Lossless text capture and paste

Represent a text item as a bundle of pasteboard representations with one canonical plain-text
fallback. Preserve supported representations as opaque `Data` so Edison does not parse and
re-serialize content unnecessarily.

Initial supported allowlist:

- `public.utf8-plain-text` / `NSPasteboard.PasteboardType.string`
- `public.rtf`
- `com.apple.flat-rtfd` when the payload is within the item size budget
- `public.html`
- Source URL/title metadata when present and safe to retain

The exact types written by the source should be recorded in priority order. On normal paste,
Edison should recreate one `NSPasteboardItem` and restore every preserved, supported
representation. The receiving application then selects its preferred type, matching normal
macOS pasteboard negotiation. Unknown types should not be persisted in 2.0 without a security
and size review.

#### Model and migration

- Add a backward-compatible rich-text payload or extend text with a custom `Codable`
  representation. Do not invalidate existing history JSON.
- Keep `plainText` mandatory for previews, indexing, accessibility, and plain-text paste.
- Store representation data in sidecar files rather than indefinitely inflating the history
  JSON. Use atomic writes and garbage-collect sidecars when items are deleted or evicted.
- Define per-representation and per-item byte limits. If rich data exceeds the limit, retain the
  exact plain text, mark the item as degraded internally, and never truncate silently.
- Deduplicate using a stable signature that includes meaningful representations, not only the
  rendered plain string. Two visually identical strings with different links or formatting may
  be distinct clipboard entries.

#### Fidelity rules

- Never call trimming, whitespace splitting/joining, typography substitution, Unicode
  normalization, or line-wrap conversion on stored text.
- Preserve tabs, repeated spaces, non-breaking spaces, CR/LF sequences, trailing newlines,
  emoji sequences, bidirectional text, and composed/decomposed Unicode exactly.
- Preview may visually wrap or collapse for layout, but preview transformations must never flow
  back into the stored payload.
- Normal paste writes rich and plain representations; plain-text paste writes exactly one plain
  string representation.

### P0 — Paste as Plain Text

Add **Paste as Plain Text** to every text item's context menu. The action should use the same
focus restoration and synthetic Command-V flow as normal paste, differing only in how the
pasteboard is populated.

- Suggested shortcut: **Shift-Return** while an item is selected. Keep Return for normal paste.
- Show the shortcut in the context menu and keyboard-help surface.
- Disable or omit the action for images and file URLs.
- Do not mutate the saved item, create a duplicate history entry, or change the user's global
  formatting preference.
- Continue suppressing Edison's own pasteboard write so it does not re-enter history.
- “Copy as Plain Text” can be a separate context action if user testing shows that copying
  without immediate paste is common; it is not required for the first 2.0 slice.

### P1 — Fast retrieval and visual clarity

After fidelity is shipped behind tests:

1. Add richer card previews for links, colors, code-like text, and formatted text without
   changing the source payload.
2. Make source application and capture time consistently visible and filterable.
3. Add search tokens such as `app:`, `type:`, `before:`, and `after:` while keeping free-text
   search simple.
4. Add pinboard/collection shortcuts: assign, remove, and jump to a collection entirely from the
   keyboard.
5. Highlight search matches only in the presentation layer.

### P1 — Privacy and control

1. Add per-application exclusions, seeded with Edison's existing concealed/transient pasteboard
   markers.
2. Offer retention choices (for example 1 day, 1 week, 1 month, or item-count only) and show
   their storage impact.
3. Add “Delete Now” and “Clear History” actions with clear scope and undo where feasible.
4. Never sync in 2.0. Explore opt-in encrypted iCloud synchronization only in a later proposal
   with threat modeling and conflict semantics.
5. Show when a rich representation was not retained because of limits, without exposing content
   in logs.

### P2 — Power workflows to evaluate after 2.0

- Multi-select paste and deliberate clipboard-item merging
- User-defined text transformations, kept separate from lossless default paste
- OCR indexing for screenshots, performed locally
- Temporary/pause-capture mode
- Quick Look and link metadata previews
- Optional encrypted device sync

These require separate product validation and must not expand the 2.0 critical path.

## Delivery plan

### Milestone 0 — Reproduction fixtures and instrumentation

1. Build pasteboard fixtures captured from TextEdit, Pages, Notes, Mail, Safari, Chrome, VS Code,
   Xcode, Terminal, Numbers, and Slack/Teams where available.
2. Record declared type order, data sizes, and a hash of each representation in debug-only test
   tooling. Never log clipboard content.
3. Add destination tests covering rich editors, plain editors, web content-editable fields,
   spreadsheets, and code editors.
4. Turn each reported spacing/formatting failure into a regression fixture before changing the
   model.

**Exit:** the current bug is reproducible, and expected type/data behavior is documented.

### Milestone 1 — Rich representation data path

1. Introduce the backward-compatible text representation model and sidecar persistence.
2. Capture the allowlisted representations from a single pasteboard item.
3. Restore all representations in one pasteboard item for copy and normal paste.
4. Update cleanup, deduplication, search extraction, exports, drag and drop, and history-limit
   eviction.

**Exit:** normal copy/paste through Edison preserves the fixture hashes/types where macOS APIs
permit it, while old histories still load.

### Milestone 2 — Explicit plain-text workflow

1. Add a paste mode (`sourceFormatting` / `plainText`) through `AppState` and
   `PasteBackCoordinator`'s clipboard writer.
2. Add context-menu actions to rail, list, and grid cards through one shared action-menu view to
   prevent layout drift.
3. Add Shift-Return handling, menu shortcut hints, accessibility labels, and telemetry-free
   debug assertions.

**Exit:** plain-text paste preserves all characters and whitespace but exposes no RTF/HTML data;
normal paste remains rich.

### Milestone 3 — Retrieval, privacy, and polish

Implement the P1 improvements in small, independently releasable changes. Measure Hub open time,
search latency, persistence time, and on-disk footprint against a full 250-item history.

**Exit:** no regression to Hub responsiveness, accessibility, privacy filters, or storage
cleanup.

### Milestone 4 — Release hardening

1. Run the cross-application manual matrix on the oldest and newest supported macOS releases.
2. Test mixed Intel/Apple Silicon builds if Intel remains supported.
3. Corrupt or remove sidecars deliberately and verify graceful plain-text fallback.
4. Upgrade an actual 1.1 history and verify favorites, collections, images, and file URLs.
5. Update privacy copy, release notes, and App Review notes with only verified behavior.

## Acceptance criteria

- Normal paste of supported rich text preserves bold, italic, underline, links, lists, tables,
  font attributes supplied in RTF/HTML, and exact plain-text whitespace where supported by the
  destination.
- Paste as Plain Text produces a pasteboard containing the exact canonical plain string and no
  rich representation.
- Tabs, multiple spaces, leading/trailing whitespace, non-breaking spaces, CR/LF, empty lines,
  and trailing newlines survive capture, app restart, search, copy, and paste unchanged.
- Existing 1.1 history decodes without data loss or a mandatory migration dialog.
- Edison's own copy/paste writes do not create duplicate history entries.
- Concealed, transient, and auto-generated content remains excluded.
- Missing/corrupt/oversized rich sidecars degrade safely to exact plain text and are observable
  in diagnostics without logging content.
- With 250 representative entries, Hub opening and search remain subjectively instant; concrete
  latency budgets will be set from Milestone 0 baseline measurements rather than invented now.

## Test strategy

### Automated

- Codable tests for legacy `.text(String)` and the new representation model
- Round-trip byte equality for plain, RTF, RTFD, and HTML fixtures
- Pasteboard writer tests asserting one item, expected type set, and exact data
- Plain-text mode tests asserting only `.string` and byte/character equality
- Whitespace and Unicode parameterized regression tests
- Sidecar atomicity, cleanup, missing-file, corruption, and size-limit tests
- Deduplication tests for equal plain text with equal and unequal rich representations
- Suppression-loop tests for both paste modes
- Context action availability and keyboard routing logic tests where separable from SwiftUI

### Manual compatibility matrix

For every source/destination pair, verify normal paste, plain-text paste, restart round trip, and
undo behavior. At minimum include TextEdit in rich/plain modes, Pages, Notes, Mail, Safari,
Chrome, VS Code, Xcode, Terminal, Numbers, and Microsoft Word/Excel when available.

## Decisions required before implementation

1. Confirm the maximum rich payload size and total disk budget from real fixture measurements.
2. Decide whether RTFD attachments belong in 2.0 or degrade to RTF/HTML/plain text.
3. Decide whether source URLs/titles are persisted as paste representations or metadata only.
4. Validate Shift-Return against current keyboard navigation and macOS conventions.
5. Validate every competitive claim above using current first-party sources once network access
   is available.

## Explicit non-goals for the 2.0 critical path

- Cloning Paste's interface or brand
- Accounts, subscriptions, collaboration, or a custom backend
- Arbitrary preservation of every vendor-specific pasteboard type
- Automatic text cleanup or “smart” whitespace correction
- Cloud sync, OCR, AI rewriting, or user-programmable transformations
