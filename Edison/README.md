# Edison source tour

Everything under this folder is compiled into the `Edison` target by both `swift build` and the Xcode project
(synchronized folders, so new files need no project edits). Tests live in [`Tests`](Tests).

The rule of thumb: **`App` wires things together, `Core` does the work, `UI` draws it.** `Core` never imports
SwiftUI, and views never hold business logic.

## App — lifecycle and orchestration

| File | Role |
|---|---|
| [`EdisonApp.swift`](App/EdisonApp.swift) | `@main` entry; declares the Settings scene and injects `AppState` |
| [`AppDelegate.swift`](App/AppDelegate.swift) | Runs Edison as a menu-bar (`.accessory`) app, owns `AppState`, builds the status item, creates the Hub and editor windows, clears scratch files on launch |
| [`AppState.swift`](App/AppState.swift) | The single `ObservableObject`: owns the services and exposes every user action (paste, copy, delete, collections, capture, editor, pause, export) |
| [`WindowRouter.swift`](App/WindowRouter.swift) | Opens, positions and dismisses the Hub shelf, editor and Settings windows across displays and Spaces |
| [`StatusBarController.swift`](App/StatusBarController.swift) | The menu-bar item and its menu, including the pause indicator |
| [`PasteBackCoordinator.swift`](App/PasteBackCoordinator.swift) | Returns focus to the app you came from and sends ⌘V through Accessibility |

## Core — services and models

| Folder | Role |
|---|---|
| [`Models`](Core/Models) | `ClipboardItem` and its payloads (text with preserved rich representations, image, file URL), collections, colours, and `ClipboardContentKind`, which classifies items as link, colour, code and so on for display only |
| [`Clipboard`](Core/Clipboard) | `ClipboardMonitor` polls `NSPasteboard`, skips concealed and transient items and honours pause; `ClipboardCoordinator` owns history mutations, deduplication, undo-delete and self-write suppression |
| [`Capture`](Core/Capture) | `CaptureEngine` (ScreenCaptureKit, area selection overlay per display), `CaptureCoordinator` (capture → editor → history), `ScreenshotDocument` (tools, annotations, undo history, export) and `AnnotationRenderer` (one Core Graphics renderer for canvas and PNG) |
| [`Persistence`](Core/Persistence) | `HistoryStore` (JSON history), `ClipboardRepresentationStore` (integrity-checked rich-text sidecars), `ImageStore` (images and thumbnails) and `TemporaryFiles` (owner-only scratch files that are cleared on close) |
| [`Search`](Core/Search) | `HistorySearchEngine`: all-words matching plus `app:` and `type:` tokens |
| [`Shortcuts`](Core/Shortcuts) | Shortcut models, validation, persistence and Carbon global hotkey registration |
| [`Settings`](Core/Settings) | `AppSettings` schema, `SettingsStore`, and launch-at-login |
| [`Log.swift`](Core/Log.swift) | OSLog categories. Log errors and states, never clipboard or screenshot content |

## UI — SwiftUI views

| Folder | Role |
|---|---|
| [`Hub`](UI/Hub) | The shelf window: `HubView` (selection, keyboard, Quick Look), `HubHeaderView` (search, filters, collections), `HubShelfView` (cards and previews), `HubListView`, `HubSupportViews` (menus, the key-handling bridge) and `HubTheme` (design tokens, glass background, window style) |
| [`EditorUI`](UI/EditorUI) | `EditorWindowView`: toolbar, style bar, canvas, gestures, keyboard and drag-out |
| [`Components`](UI/Components) | `SettingsView` and the shortcut recorder row |

## How a copy becomes a paste

1. `ClipboardMonitor` sees the pasteboard change, reads every supported representation off the main thread and
   builds a `ClipboardItem`.
2. `ClipboardCoordinator` stores rich data as sidecars, deduplicates, trims to the history limit and persists.
3. `HubView` renders the filtered items from `AppState`; selecting one and pressing Return calls
   `AppState.pasteSelection`.
4. `ClipboardCoordinator` writes the original representations back (or only the plain string), marking the write
   as Edison's own so it doesn't re-enter history, and `PasteBackCoordinator` re-activates the previous app and
   sends ⌘V.

## How a capture becomes an image

1. A hotkey or menu item asks `CaptureEngine` for an area, window, display or the previous area.
2. `CaptureCoordinator` wraps the PNG in a `ScreenshotSession` and opens the editor (or keeps it, per Settings).
3. The editor commits annotation snapshots to the session's undo history; the canvas draws them with
   `ScreenshotAnnotationRenderer`.
4. Copy, Save, Keep or drag-out renders the same annotations into a PNG and, where relevant, adds it to history.

## Tests

`swift test` runs Swift Testing suites covering search, clipboard capture and fidelity (including AppKit
pasteboard integration), paste-back timing, shortcuts, capture sessions, collections, window routing and app
lifecycle. Shared fixtures are in [`Tests/TestHelpers.swift`](Tests/TestHelpers.swift).
