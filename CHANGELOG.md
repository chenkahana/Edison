# Changelog

## 2.2 — unreleased

### Hub
- Closing the Hub with Esc or its shortcut gives focus back to the app you were in, and so does cancelling a capture
  or a capture that only goes to history. Before, keys went nowhere until you clicked that app.
- Dragging a card out offers exactly what a paste writes: formatted text keeps its RTF and HTML, an image drops as
  its PNG, a file drops as the file. Before, every drag offered plain text first (empty for images, a path for files).
- Paste-back presses ⌘V through your keyboard layout. On Dvorak it used to send ⌘. (the key where QWERTY has V).
- Keys typed right after ⇧⌘V reach search. The Hub only took keys once its 0.2 s slide-in finished, so the first
  letters were lost.
- The Hub opens on the display with the pointer. It used to open on whichever display it was last on.
- Esc clears the search first and closes the Hub on the next press, as in other Mac search fields.
- Deleting a collection asks first and says its items stay in your history; the trash button is labelled for
  VoiceOver and has a tooltip.
- ⇧Return on an image or file beeps, since only text has a plain-text form. It used to do nothing.
- Empty Favorites and empty collections say so and how to fill them. Before, empty Favorites said "No History
  Yet" and a new collection said "No Matching Items".
- ⌘Z in the Hub undoes the last delete while its Undo toast is showing; with nothing to undo it beeps.
- Pasting without Accessibility access says the item is copied and ⌘V pastes it; OK closes the Hub so you can.
  Before, the alert only said Edison "needs" access and to retry.
- Items older than a week show their date ("Nov 3", or "Nov 3, 2025" from another year) instead of "16d".
- Double-clicking a card to paste it registers reliably. Before, a single-tap and a double-tap gesture on the
  same card left SwiftUI to resolve the conflict, and it favoured the single tap.
- Export… names text and images like screenshots, after the item's date, and copies a file item straight to the
  new place instead of loading it into memory first. Export and Share have their ellipses.
- Share opens at the card you chose it from, not the Hub's centre. Text shares with its formatting (RTF/HTML)
  instead of plain text, and an image shares as its stored PNG under its file name instead of a re-decoded image.
- Quick Look writes its preview copy once when it opens (and when the selection changes), not on every redraw.
- Quick Look no longer closes the Hub out from under it — it's a separate panel, not a sheet, so it taking
  focus used to read as "focus left Edison." ←/→ in Quick Look now move through your whole visible history,
  like Finder, and keep the Hub's selection in sync.
- The selected card or row has the same blue ring whatever the item is. It used to take the item's type colour,
  which changed from card to card and could vanish on white or grey items.
- Card metadata (size, line count, dimensions) is easier to read: it uses the secondary text colour, about 5.7:1
  on white instead of 2.7:1.
- With Increase Contrast on, the Hub's glass stroke, dividers and card fills switch to stronger variants instead
  of staying at their standard translucency.
- The Hub no longer takes focus from the app you're in: it's a panel that takes your typing while that app stays
  active, so its selection stays lit and paste lands there without a re-activation.
- The Hub opens fresh each time: no leftover search, type filter or collection, newest item selected.
- Search and type/collection filtering run once per change instead of several times per Hub render — a single
  render used to re-run the full search over your whole history half a dozen times.
- Cards show text exactly as it will paste. Before, anything containing `- `, `` ` ``, `**` or similar was
  rendered as Markdown (joining single line breaks and hiding those characters), and JSON was pretty-printed
  with its keys sorted — neither matched what ⌘V or a drag-out actually produced.
- Shelf/List/Grid and All/Favorites are remembered across launches, like any other view preference. Before,
  every relaunch went back to Shelf and All.
- Search shows how many items matched, and highlights the matching text on every card. Before, results swapped
  with no feedback on what actually matched.
- A card reads as one VoiceOver element (not its text, metadata and badges separately), announces when it's
  selected, says how long ago it was copied in words and which app it came from (instead of a bare "5m", read as
  "5 meters"), and offers Paste, Copy, Favorite and Delete as VoiceOver actions.
- The Hub's window slide, scroll-to-selection and the undo toast respect Reduce Motion: with it on, they apply
  instantly instead of animating. Their durations are now named tokens instead of bare numbers at each call site.
- Cards and list rows are concentric with the Hub window: an 8 pt radius 20 pt inside the window's 28 pt radius,
  instead of 18 pt — the two no longer curve at different rates at the corner.
- A shelf card's text line count is derived from the actual font's line height instead of a fixed 20 pt guess,
  so the limit tracks what's really drawn; cards now fit a line or two more of text before truncating.
- Opening the Hub only clears your search and the selected collection. The Type filter now carries over like the
  Shelf/List/Grid view does, instead of resetting to All every time.
- Add Favorite and Remove Favorite read the same whether you reach them from the right-click menu or from
  VoiceOver's rotor; the rotor used to say "Add to Favorites" for the same action.
- The editor and Settings now share one "Edison is a regular app" state: opening either while the other is
  already open, then closing just one, keeps the Dock icon and menu bar until the last one closes. Before,
  closing the editor always dropped back to menu-bar-only even with Settings still open.
- The Hub and editor's 34 scattered `.system(size:...)` font declarations now snap to one 7-step type
  ramp (`HubTheme.Step`/`HubTheme.TypeRamp`), each step documented with its nearest system text style.
  Two sites moved to the nearest step (code preview 11.5→11pt, link preview title 17→18pt); the other 32
  were already on a step and are pixel-identical to before.

### Intelligence
- Text copied from a terminal gets its own Terminal label instead of Code. Text from Terminal, iTerm2, Ghostty,
  Warp, kitty, Alacritty, WezTerm, Hyper, Tabby and Rio is Terminal unless it's plain source code (say, a file you
  `cat`). From other apps, shell prompts, `ls -l` listings, timestamped logs, stack traces, compiler errors and git
  output mark it as Terminal. Terminal cards are monospaced, like Code.
- Code detection reads less into prose: a list with "->" in it, or a sentence with "return" in it, stays Text.
  Shell scripts with a `#!` line are Code.
- On a sample of 84 real clips, 81 now get the right label, up from 43. No terminal output is labelled Code any more
  (9 were before).
- Search highlights matches on Code and Terminal cards too, and list rows tell VoiceOver the item's kind.
- With Apple Intelligence on (macOS 26 or later), Edison gives each text item one to three topic tags, using the
  on-device model. Searching for a topic finds items tagged with it, and VoiceOver reads the tags. Where Edison's
  own rules can't tell text, code and terminal output apart, the model's label decides; on the 84-clip sample
  that's 82 right instead of 81.
- New items are tagged in the background right after you copy them, one at a time and never on the main thread;
  older history is worked through a few items at a time. Nothing runs in Low Power Mode. Copying the same thing
  again keeps its tags.
- Settings › Intelligence: turn labelling on or off (on by default), see Apple Intelligence's status, and process
  your existing history now, with progress. It all stays on your Mac.
- Images and screenshots are read on your Mac with Vision (macOS 14 and later): the text in them, what kind of
  picture they are (document, screenshot…), and any QR code or barcode. Search finds a screenshot by the words in
  it, and VoiceOver reads them.
- An image with a QR code link shows a QR mark on its card; click it, or choose Open QR Code Link, to open the link.
- A screenshot that looks almost the same as an earlier one shows a "similar" mark, so repeats are easy to spot.
- With Apple Intelligence on, screenshots get topic tags from their text. On macOS 27 the on-device model reads
  the image itself and writes a one-line caption, which VoiceOver reads and search finds.

### Capture
- After a capture is refused for lack of Screen Recording access, the alert's Open System Settings button opens
  Privacy & Security › Screen Recording. Before, it did nothing after the first system prompt.
- Area selection shows the crosshair cursor (window selection keeps the arrow); the arrow comes back when the
  capture ends.
- Captures play the macOS screenshot sound, unless "Play user interface sound effects" is off.
- After a capture a thumbnail appears in the corner for 5 seconds, as with ⇧⌘5: click it to annotate, drag it
  into any app, or swipe it away; the capture is already in history. Settings › Capture › Go Straight to the Editor
  brings back the old behaviour.
- An area selection stays on the display it started on, so what you selected is what you get. Before, a drag that
  crossed onto a second display was captured cut off at its edge.
- The window-capture highlight is a soft tinted fill, like the system's own screenshot tool, instead of a thick
  orange outline; the overlay's instructions keep a shadow so they read over bright content.
- A capture or editor error appears as a floating banner even when the Hub is closed, with only the actions that
  error has (a "Screen Recording" button no longer shows up for errors that aren't about permission). Before, it
  was a banner inside the Hub, usually not open during a capture.
- Screen Recording's prompt and status update as soon as Edison regains focus, instead of needing Settings ›
  Refresh Status; once access is granted mid-session, Settings and the prompt offer Quit & Reopen Edison, since
  macOS only applies the grant after a relaunch.
- Moving the pointer during area selection no longer scans every on-screen window — that lookup only matters in
  window-selection mode, where the result is shown; area mode was discarding it on every move.
- Moving the pointer during a capture no longer redraws every display's full-screen overlay on every pixel moved;
  each one now redraws only when something it actually shows has changed.
- An area capture is cropped from the exact frame the overlay showed while you were selecting, not a fresh capture
  taken after it closes — so a video frame, tooltip or hover highlight that changed in between can no longer make
  the result differ from what you selected.

### Settings
- Clear History… asks first and says how many items go (favorites and screenshots included). Collections stay,
  emptied. Before, one click deleted everything, collections too, with no warning.
- Restore All Defaults… asks first, and says when going back to the default history limit (250) deletes your
  oldest items.
- History Limit and a new Keep History (age) setting are menus, not a 25-step stepper; lowering either asks
  first and says how many items it deletes (favorites are kept). Previously the stepper made an accidental jump
  unlikely only because each click moved it by 25.
- Storage Usage is recomputed off the main thread, so changing a setting with a large history no longer stalls
  the window while it walks the storage folder.
- Export Diagnostics… has its Mac ellipsis, since it opens a save dialog.
- Removed Start Hidden When Launched at Login: it was never read anywhere, so toggling it did nothing.

### Menu bar
- Capture Previous Area and Edit Last Screenshot are dimmed when there's no area or screenshot yet, instead of
  doing nothing.
- The menu shows each action's shortcut, including ones you set in Settings, and uses Mac titles: Settings… and
  Quit Edison.
- Clicking the menu-bar icon toggles the Hub; right-click or Control-click shows the menu. (Option-click
  used to show the menu instead of Control-click, which doesn't match how every other menu-bar icon on the Mac
  responds to a secondary click.)
- A vector menu-bar icon, sharp at every scale.

### Screenshot editor
- The editor's buttons say what they do: Save…, Add to History, Copy (now the highlighted button) and Close. The
  highlighted button used to be Done, which could lead to discarding changes.
- Save… opens as a sheet on the editor and writes the file in the background, so the rest of Edison keeps
  working while you choose a place.
- The colour swatches have names (VoiceOver reads "Red, selected", and each has a tooltip) instead of all
  reading "Colour".
- While the editor is open Edison has a Dock icon, ⌘-Tab and a menu bar (⌘W closes the editor); it goes back to
  the menu bar when the editor closes.
- The cursor follows what's under it: resize arrows over a handle, a hand over a movable mark, an I-beam for
  Text, a crosshair otherwise. It used to be only arrow (Select) or crosshair (everything else).
- A Shift-snapped line, shape or crop (45°, square, circle) gives a trackpad tap the moment it snaps.
- Ten arrow-key nudges now undo in one ⌘Z instead of ten.
- Dragging the finished image out renders and writes it only once the drag needs it, not when you pick it up.

### Shortcuts
- New installs use ⌃⌥⌘V (Hub) and ⌃⌥⌘S (Capture Area), which no macOS or app command uses. ⇧⌘V and ⇧⌘S took
  Paste and Match Style and Save As from every app. If you used Edison before, your shortcuts don't change.

### Copy
- One name per thing: Hub, Capture Area, Annotate Last Screenshot…, Image, Pixelation Size; Mac ellipses
  (Calculating…, Type Shortcut…) and one permission button, Open System Settings….

### First run
- New installs get one welcome window: the two shortcuts, and Screen Recording and Accessibility with live
  status. It never comes back once you click Done.

## 2.1 — 2026-11-12

### Install and updates
- Download Edison as a notarized DMG from GitHub Releases (the README's Download for Mac button).
- Edison updates itself with Sparkle: after asking, it checks once a day, and from the menu bar's Check for Updates…. Updates install only if they're signed with Edison's key.

### Capture fixes
- The Hub (⇧⌘V) and the screenshot editor always open. They were SwiftUI scenes that macOS sometimes never created at launch, leaving nothing to show.
- "Copy + Open Editor" copies the capture to the clipboard (and history) immediately.
- Area and window selection now work on every display, including ones left of or above the main display.
- Area captures now grab exactly the selected region, which used to be mirrored vertically.

### Screenshot editor
- New tools: line, ellipse, freehand pen, highlighter, numbered step counter, and pixelate (replaces the soft blur, which could leak text).
- Icon toolbar with single-key tool shortcuts (V A L R O P H T N B C), Shift to snap lines to 45° and draw squares/circles, arrow-key nudge, ⌘D duplicate, ⌘[ / ⌘] size, ⌘↩ copy and close.
- One renderer draws both the canvas and the exported PNG, so arrowheads, pixelation, text, and the legibility halo look identical before and after export.
- Always-visible colour and size bar; the last-used style is remembered.
- Text is typed in place and can be re-edited; crop previews with a dimmed mask instead of zooming mid-drag, and can be reset.
- Drag the finished image straight from the editor into any app.
- Fix: crops and Retina exports now use correct pixel coordinates and keep their point size.

### Hub
- Cards show what an item is — link (site and path), colour (live swatch), code (monospaced), text, image (pixel size), file (Finder icon and folder) — with source app and favourite in a tinted header.
- Hold ⌘ to reveal ⌘1–⌘9 quick-paste badges.
- Search with `app:` and `type:` tokens; every word must match. New Links, Files, and Colours type filters.
- Annotate any history image (⌘E or context menu) without overwriting the original; ⌘O opens links and reveals files.
- Pause / resume clipboard history from the menu bar, a bindable shortcut, or the Hub; the menu-bar icon dims while paused and nothing copied in the meantime is captured on resume.
- Thumbnails are decoded once and cached instead of on every redraw.

### Open source
- Relicensed under the Mozilla Public License 2.0.
- New README, source tour, architecture and privacy docs; contributing, security, support, code-of-conduct and
  third-party notices; issue and pull-request templates and CODEOWNERS.
- Quick Look previews and drag-out images now live in an owner-only temporary folder that is cleared when they close
  and at launch, so deleted items don't linger on disk.
- CI runs with read-only permissions, a pinned checkout action and no persisted credentials; Dependabot tracks
  Actions.
- Internal planning notes and per-folder agent files are no longer published; an unused build-settings file is no
  longer copied into the app bundle.

## 2.0 — 2026-08-08

### Clipboard fidelity

- Preserve ordered plain-text, RTF, RTFD, and HTML pasteboard representations without parsing or reserialization.
- Restore captured source formatting by default and fall back safely to the exact canonical plain string when rich sidecars are unavailable or corrupt.
- Add **Paste as Plain Text** to item context menus and Shift-Return/Shift-keypad-Enter handling.
- Keep representation sidecars bounded, integrity-checked, reconciled at startup, and deleted with their history items.

### Verification and release hardening

- Add isolated AppKit integration coverage for capture, rich/plain replay, destination negotiation, restart persistence, legacy history migration, corruption fallback, cleanup, mode routing, and self-write suppression.
- Set the application marketing version to 2.0 and enforce warning-free Release builds.
- Extend CI to build Debug and Release configurations and produce a validated unsigned macOS archive.

## 1.5 — 2026-04-18

### Stability & Performance
- Decompose `AppState` into focused coordinators: `ClipboardCoordinator` (history mutation, clipboard writes, `suppressedClipboardPayloads`) and `CaptureCoordinator` (screenshot session lifecycle). AppState now orchestrates, not implements. Public API preserved; no view changes required.
- Decompose `HubView.swift` (1636 → 665 lines) into `HubHeaderView`, `HubShelfView`, `HubListView`, `HubSupportViews`. Shelf and list share `HubClipboardTextView` via the support file.
- Add `os_signpost` intervals for Hub toggle, search filter, history load, and capture. Enables performance regression detection in Instruments.
- Fix potential observer leak at `AppState.deinit` (was async `Task { @MainActor }`; now synchronous `NotificationCenter.removeObserver`).
- Fix event monitor leak safety net in `CaptureEngine.RegionSelectionSession` deinit.

### Tests
- Split `EdisonTests.swift` (927 lines) into 9 domain files: Search, Clipboard, PasteBack, Shortcuts, Capture, Collection, AppStateLifecycle, ClipboardCoordinator, CaptureCoordinator. Shared fixtures in `TestHelpers.swift`.
- New golden tests covering the refactor surface:
  - `PasteBackCoordinator` timing: success, accessibility-denied, nil-target (3 cases)
  - `AppState` lifecycle: no-runtime-services init, deinit observer safety, settings round-trip (3 cases)
  - `WindowRouter` lifecycle: toggle, dismiss, editor open/close (4 cases)
  - `ClipboardCoordinator` in isolation: suppression, delete/undo, favorite (3 cases)
  - `CaptureCoordinator` in isolation: success, failure, commit ordering (3 cases)
- Test count: 20 → 36. Dual Swift Testing + XCTest framework support preserved.

### Tooling
- Add `Edison/Configs/Release.xcconfig` with `GCC_TREAT_WARNINGS_AS_ERRORS=YES` and `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`. Wiring to Xcode Release configuration is a manual follow-up (see TODO in the xcconfig).

### Internal
- No user-facing feature changes. No product scope changes. No new dependencies.

### Follow-ups deferred from v1.5
- Wire `Edison/Configs/Release.xcconfig` into `Edison.xcodeproj` Release configuration.
- Evaluate `CaptureEngine` protocol extraction if capture bugs emerge (was Option B; deferred per P2 "no new abstractions without clear need").
- Consider SwiftUI `@Observable` migration when minimum deployment target moves to macOS 17+.

## 1.1 — 2026-04-11

Release hardening: images moved out of the history file into an image store, structured logging, visible capture and permission errors, and repository governance (#22).

## 1.0

Initial release.
