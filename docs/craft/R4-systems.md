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
