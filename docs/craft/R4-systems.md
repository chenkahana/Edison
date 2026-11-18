# R4 Systems

Six small systems that most R2 findings reduce to. Each one says what exists, the proposal, how it reconciles with
`docs/ui-style-guide.md`, and which findings it closes. Names follow the Boaz plan (`quick`, `standard`,
`emphasized`, `gesture`) so the three apps can share them.

## R4.1 Motion tokens

**Today.** Three voices: AppKit `easeInEaseOut` 0.20/0.18 s for the shelf frame (`WindowRouter.swift:247,266`),
SwiftUI `easeInOut 0.16` for scroll-to-selection (`HubView.swift:485`), an untokenised `spring(0.3, 0.8)` for toasts
(`HubView.swift:220,239`), plus `HubTheme.Anim` (`fast/standard/emphasis` durations and `spring/fastSpring`,
`HubTheme.swift:26-32`), of which only `fastSpring` is used. No Reduce Motion handling anywhere.

**Proposal.** Replace `HubTheme.Anim` with four tokens and one rule: every animated call site names a token.

| Token | SwiftUI value | Use |
|---|---|---|
| `quick` | `.snappy(duration: 0.16)` | Selection ring move, hover, ⌘ quick-paste badges, segmented state |
| `standard` | `.smooth(duration: 0.24)` | Shelf content entrance and exit, filter/search result changes, card insert and delete, toasts |
| `emphasized` | `.spring(response: 0.32, dampingFraction: 0.82)` (today's `HubTheme.Anim.spring`) | Drag lift (scale 1.02 + deeper shadow), Quick Look/preview expansion |
| `gesture` | `.interactiveSpring(response: 0.28, dampingFraction: 0.86)` | Editor: annotation drag/resize settle, crop handle release |

Rules:

1. **The window doesn't animate; the content does.** Order the shelf in fully placed and key on the first frame,
   then animate the content `standard`: opacity 0→1 and a 12 pt upward offset. This closes E08 (type-ahead) without
   losing the "comes from the bottom" feel. Exit: content fades `quick`, then `orderOut`. Paste exit stays instant.
2. **Nothing animates on first show of existing items.** Card insert/delete transitions apply only to changes while
   the shelf is open (`.transition(.opacity.combined(with: .scale(0.96)))` under `standard`).
3. **Selection moves, it doesn't blink.** One selection ring drawn once with `matchedGeometryEffect` under `quick`.
   Scroll-to-selection uses the same `quick`.
4. **Reduce Motion.** A single `Motion.resolve(_:)` helper returns `.easeInOut(duration: 0.16)` opacity-only when
   `accessibilityReduceMotion` (SwiftUI) or `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` (AppKit) is
   on; offsets and scales become 0.

**Call-site map.**

| Call site | Today | Token |
|---|---|---|
| Shelf in/out `WindowRouter.swift:233-273` | Frame slide 0.20/0.18 | Content `standard` in, `quick` out; window static |
| Scroll to selection `HubView.swift:485` | `easeInOut 0.16` | `quick` |
| Quick-paste badge `HubShelfView.swift:149` | `fastSpring` | `quick` |
| Undo toast / error banner `HubView.swift:220,239` | `spring(0.3, 0.8)` | `standard` |
| Selection, results, insert/delete | none | `quick` / `standard` |
| Editor annotation settle | none | `gesture` |

**Style guide reconciliation.** Replace the "Animation" table (`anim.fast 0.12`, `anim.standard 0.20`,
`anim.emphasis 0.28`, `curve.standard easeInOut`, `curve.spring`) with the four tokens above; keep its "Recommended
use" mapping (hover/focus → `quick`, open/close → `standard`, preview and drag lift → `emphasized`).

**Closes:** E08, E11, E12, E81 (Reduce Motion half), drag-lift half of E73.

## R4.2 Haptic map

**Today.** None (`NSHapticFeedbackManager` unused). Mac haptics only fire on a Force Touch trackpad and only while
the pointer is driving a drag, so they belong to direct manipulation, never to keyboard actions or the Hub list.

**Proposal.** One helper, `Haptics.perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern)`, called with
`performanceTime: .now`, fired only on the transition into a snapped state (never repeatedly while it stays
snapped).

| Moment | Surface | Pattern |
|---|---|---|
| Line/arrow snaps to a 45° step while Shift is held | Editor | `.alignment` |
| Rectangle/ellipse/crop becomes square/circle under Shift | Editor | `.alignment` |
| Annotation edge or centre aligns with another annotation or the image centre (once snapping guides exist) | Editor | `.alignment` |
| Crop handle reaches the image edge | Editor | `.generic` |
| Size preset steps with ⌘[ / ⌘] | Editor | none (keyboard) |
| Area selection snaps to a window edge (if magnetic edges are built) | Capture overlay | `.alignment` |
| Card dragged over a collection drop target (once E38 lands) | Hub | `.generic` on enter |
| Selection, paste, delete, search | Hub | none |

**Reconciliation.** The style guide has no haptics section; add this table under "Interaction model".

**Closes:** E54 (and gives E38 its feedback).

## R4.3 Layout tokens

**Today.** `HubTheme.Radius` (window 28, card 18, menu 12, pill 999) and `HubTheme.Space` (4–24) exist and are mostly
used in the Hub; the editor uses literals (radius 4, 6, 7, 10; padding 4, 7). Shelf is 278 pt tall
(`HubTheme.swift:21`) against the guide's 156 compact / 240 regular. Content padding is 20 pt, so 18 pt cards inside
a 28 pt window aren't concentric (E21). Selection is a per-type coloured stroke (E10).

**Proposal.**

| Token | Value | Rule |
|---|---|---|
| `radius.shelf` | 28 | Window corners, continuous |
| `inset.shelf` | 12 (`space.3`) | Padding between shelf edge and the card row |
| `radius.card` | `radius.shelf − inset.shelf` = 16 | Derived, never typed |
| `inset.card` | 12 | Card content padding |
| `radius.inner` | `max(4, radius.card − inset.card)` = 4 | Image previews, swatches, code blocks inside a card; or let images go full-bleed and inherit `radius.card` |
| `radius.control` | 8 | Editor tool buttons, chips, style bar (replaces 4/6/7/10 literals) |
| `radius.pill` | capsule | Search pill, toasts |
| `space.1…6` | 4, 8, 12, 16, 20, 24 | Unchanged; literals in `.padding()`/`spacing:` are lint errors outside `HubTheme` |
| `shelf.height` | 278 | Code wins; the guide's 240 predates the header row. A compact density (≈200) is a later setting. |
| `card.side` | 148–220, derived from shelf height | Unchanged (`HubTheme.swift:34-37`) |
| `selection.ring` | 2 pt `Color.accentColor` stroke + `selectionFill`, same on every card | Replaces the per-type stroke; type colour stays in the header strip |
| `hit.min` | 28×28 pt | Header icon buttons (collection trash, toast close, editor icons) |
| `shadow.card` | ambient `0 1 6 rgba(0,0,0,.08)` + key `0 6 16 rgba(0,0,0,.12)`; dark ×2 opacity | The guide's "≈40 % lighter for nested cards"; also halves blur cost per card (E22) |

**Reconciliation.** Update the guide's "Recommended default sizes" (shelf 278; card side derived), add the concentric
rule and `selection.ring` under "Radii", and replace the card shadow line with `shadow.card`.

**Closes:** E10, E21 (geometry half), E49 (highlight radius), part of E22 and E20 (header layout once the composer
moves to a menu).

## R4.4 Type ramp

**Today.** 35 `.font(.system(size:))` calls (R0.2). Cards use 14 pt medium body, 17 pt bold link host, 12 pt semibold
header and footer, 11.5 pt monospaced code; the empty state 18/13; the capture overlay draws 13/11 pt
`NSFont.systemFont`. The guide's ramp is 13 shelf title / 12 card body / 10 meta / 10 key hint / 13 search. Neither
uses text styles, so nothing follows the system's text-size settings.

**Proposal.** Text styles only (macOS sizes in brackets), with `.monospacedDigit()` on anything that counts.

| Role | Style | Replaces |
|---|---|---|
| Search text | `.body` (13) | `HubHeaderView.swift:77` |
| Card body text | `.body` (13) | 14 medium `HubShelfView.swift:267`, list 13 |
| Link host | `.title3.weight(.semibold)` (15) | 17 bold `HubShelfView.swift:274` |
| Link path, file folder | `.callout` (12), secondary | 12 / 11 |
| Code and JSON preview | `.callout.monospaced()` (12) | 11.5 and `fontSize − 1` |
| Card header (type name) | `.subheadline.weight(.semibold)` (11) | 12 semibold `HubShelfView.swift:212` |
| Card footer metadata | `.caption.monospacedDigit()` (10), `textSecondary` | 12 semibold / tertiary `HubShelfView.swift:450-458` (also fixes E17) |
| Quick-paste badge | `.callout.weight(.bold).monospacedDigit()`, rounded | 12 rounded bold |
| Empty-state title / body | `ContentUnavailableView` (system) | 18 / 13 `HubView.swift:249,257` |
| Toast and banner | `.callout` (12) | 12 medium |
| Editor dimensions, zoom | `.caption.monospacedDigit()` | 11 `EditorWindowView.swift:276,402` |
| Capture overlay hint and W×H | `NSFont.preferredFont(forTextStyle: .subheadline)`, `monospacedDigitSystemFont` for numbers | 13/11 `CaptureEngine.swift:584-623` |

**Truncation.** Text: tail. File names: middle (keeps the extension). Folder paths: head (already). Link hosts:
middle, so `docs.github.com` keeps its registrable end. Collection names: tail.

**Tabular digits.** Timestamps, character and line counts, image dimensions (card, overlay badge, editor), quick-paste
numbers, storage size, history limit.

**Reconciliation.** Replace the guide's size table with the role → text style table; keep SF Pro/SF Mono and the
SF Symbols rule.

**Closes:** E21 (type half), E17 (with `textSecondary` for metadata), E24 (digits), part of E49.

## R4.5 Copy rules (English only, String Catalog)

**Today.** All copy is literal (0 `String(localized:)`, no `.xcstrings`); five names for the shelf, three for area
capture, two for pixelate (R1 "Names in use"); missing ellipses; hand-rolled plurals ("1 char") and timestamps
("45d"); one British spelling ("Colour").

**Rules.**

1. **One catalog, English only.** `Edison/Resources/Localizable.xcstrings` with `defaultLocalization: "en"` in
   `Package.swift` and the Xcode project. Every user-facing string goes through `String(localized:)` /
   `LocalizedStringKey` with a comment saying where it appears. It exists for copy review, plurals and grammar
   agreement, not translation (Chen, 2026-11-18).
2. **Capitalisation (Apple HIG).** Title Case for menu items, buttons, window and pane titles, segmented labels.
   Sentence case for toggle/checkbox labels, descriptions, hints, placeholders, toasts and alert body text. Today's
   Settings toggles ("Open Editor After Capture") become "Open editor after capture".
3. **Ellipsis.** A real "…" on any item that opens a further step: Settings…, Export…, Share…, Save…, New
   Collection…, Choose…, Check for Updates… (already), and on progress text ("Calculating…").
4. **State titles, not slashes.** "Pause Clipboard History" / "Resume Clipboard History", never "Pause / Resume".
5. **Errors and permissions.** First sentence says what happened, second what to do; the button names the
   destination: "Open Screen Recording Settings", "Quit & Reopen". No "Fix Access".
6. **Numbers and dates through `FormatStyle`.** Counts with automatic grammar agreement
   (`^[\(n) line](inflect: true)`), sizes with `.byteCount(style: .file)`, recent times with
   `Date.RelativeFormatStyle(presentation: .numeric, unitsStyle: .narrow)` up to 6 days, then `.dateTime.month().day()`.
7. **American spelling** throughout ("Color").

**Glossary (one name per concept).** Proposed; the first two need Chen's pick.

| Concept | Use | Retire |
|---|---|---|
| The shelf | **Hub** (menu "Open Hub", shortcut "Open Hub", VoiceOver "Edison Hub") | "Open Edison", "shelf" in copy (keep "Shelf" only as the layout name) |
| Area capture | **Capture Area** | "Capture Screenshot" for the area action |
| Favorites | **Favorite** (style guide says "Pin") | "Pin" unless Chen prefers Paste's word |
| Pixelate | **Pixelate** | "Blur Strength" → "Pixelation Size" |
| Image items | **Image**; **Screenshot** only for Edison captures | "Image / Screenshot", "Clipboard image" |
| Editor | **Screenshot Editor**; action **Annotate…** | "Edit Last Screenshot" → "Annotate Last Screenshot…" |
| Editor exits | **Copy**, **Save…**, **Add to History** (was Keep), **Close** (was Done; discards with a prompt) | "Keep", "Done" |

**Closes:** E04, E24, E42 (rename), E51, E64, E69 (copy), E75 (ellipsis), E79 (spelling), and the naming rows in R1.
