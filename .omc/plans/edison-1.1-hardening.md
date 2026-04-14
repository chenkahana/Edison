# Edison 1.1 Hardening — Work Plan

## Requirements Summary

Address all issues identified in `docs/1.1 plan/issues analysis.md` and ship Edison 1.1 via a single PR. The marketing version is already set to `1.1` in `project.pbxproj`; this plan covers all correctness, security, reliability, and polish fixes needed before that version ships.

---

## Acceptance Criteria

- [ ] `CaptureEngine.runScreencapture` termination handler uses the handler parameter (no retain cycle); `[weak self]` used for `self` capture
- [ ] `MACOSX_DEPLOYMENT_TARGET` is `14.0` in both build configurations in `project.pbxproj` (lines 189 and 247)
- [ ] `CURRENT_PROJECT_VERSION` bumped to `3` in `project.pbxproj` (lines 263 and 313) to mark the 1.1 build
- [ ] `ClipboardImageData` stores no `Data` blobs inline; images and thumbnails are written to `{AppSupport}/Edison/images/` as PNG files; `ClipboardItem` JSON stores only relative file paths
- [ ] `ClipboardPayload.fileURL` persists a security-scoped bookmark (base64 string) instead of a raw URL; resolved on demand with `startAccessingSecurityScopedResource()`
- [ ] Capture failure (non-zero exit or missing output file) posts an `edisonCaptureFailed` notification with a reason string; `AppState` surfaces an in-app error banner with "Enable Screen Recording" link
- [ ] `AppState.pasteItem` calls `AXIsProcessTrustedWithOptions` with the prompt dictionary on first use (not `AXIsProcessTrusted`); shows a one-time Settings banner if not trusted
- [ ] `HotKeyCenter.apply` checks `RegisterEventHotKey` return status; skips failed registrations and stores the failure reason for Settings UI display
- [ ] `KeyRecorderField` has a `deinit` that calls `removeMonitor()` to prevent leaked local event monitors
- [ ] `HistoryStore.save` logs write errors via `Logger` instead of silently swallowing them with `try?`
- [ ] `OSLog`/`Logger` instances defined for subsystems: `capture`, `store`, `shortcuts`, `clipboard`, `permissions`
- [ ] CI workflow adds an `xcodebuild test` job targeting the `Edison - Clipboard Manager` scheme
- [ ] `LICENSE` (MIT), `SECURITY.md`, and `CONTRIBUTING.md` exist in repo root
- [ ] All changes compile cleanly under Swift Package Manager (`swift build`) and Xcode scheme

---

## Implementation Steps

### Step 1 — Fix retain-cycle in CaptureEngine (Critical)
**File:** `Edison/Core/Capture/CaptureEngine.swift` lines 54–83

Change the termination handler to:
```swift
process.terminationHandler = { [weak self] process in
    DispatchQueue.main.async {
        defer { try? FileManager.default.removeItem(at: outputURL) }
        guard process.terminationStatus == 0,
              let imageData = try? Data(contentsOf: outputURL) else {
            Log.capture.error("screencapture failed with status \(process.terminationStatus)")
            NotificationCenter.default.post(
                name: .edisonCaptureFailed,
                object: nil,
                userInfo: ["reason": "screencapture exited \(process.terminationStatus)"]
            )
            return
        }
        self?.postCaptureNotification(imageData: imageData)
    }
}
```
- Use the handler block parameter `process` (not the outer captured `process`)
- Capture `self` weakly
- Post `edisonCaptureFailed` notification on failure

### Step 2 — Fix deployment target (Critical)
**File:** `Edison.xcodeproj/project.pbxproj` lines 189 and 247

Replace both occurrences:
```
MACOSX_DEPLOYMENT_TARGET = 26.3;
→
MACOSX_DEPLOYMENT_TARGET = 14.0;
```

Also bump `CURRENT_PROJECT_VERSION` from `2` to `3` at lines 263 and 313.

### Step 3 — Add OSLog Logger (prerequisite for Steps 1, 4, 7, 8)
**File:** New `Edison/Core/Log.swift`

```swift
import OSLog

enum Log {
    static let capture    = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Edison", category: "capture")
    static let store      = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Edison", category: "store")
    static let shortcuts  = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Edison", category: "shortcuts")
    static let clipboard  = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Edison", category: "clipboard")
    static let permissions = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Edison", category: "permissions")
}
```

Add `Log.swift` to the Xcode project target and SwiftPM Sources.

### Step 4 — Move image blobs out of JSON (High)
**Files:** `Edison/Core/Models/ClipboardItem.swift`, `Edison/Core/Persistence/HistoryStore.swift`, `Edison/Core/Clipboard/ImageProcessing.swift`

**ClipboardItem.swift — change ClipboardImageData:**
```swift
// Before
struct ClipboardImageData: Codable, Hashable {
    let data: Data
    let thumbnailData: Data
}

// After
struct ClipboardImageData: Codable, Hashable {
    let imagePath: String      // relative path under AppSupport/Edison/images/
    let thumbnailPath: String
}
```

**New ImageStore helper** (`Edison/Core/Persistence/ImageStore.swift`):
- `static func save(imageData: Data, id: UUID) throws -> String` — writes PNG to `{AppSupport}/Edison/images/{id}.png`, returns relative path
- `static func saveThumbnail(data: Data, id: UUID) throws -> String` — writes to `{AppSupport}/Edison/images/{id}-thumb.png`
- `static func load(relativePath: String) throws -> Data` — resolves path and reads
- `static func delete(relativePath: String)` — removes file; called during history cleanup

**HistoryStore migration:** On load, if a `ClipboardItem` decodes with the old schema (inline `data` fields present), migrate by writing the blobs to disk and re-encoding with paths. Quarantine-on-corruption logic remains unchanged.

**Retention cleanup:** When `HistoryStore` enforces the 250-item cap, call `ImageStore.delete` for evicted items' paths.

### Step 5 — Security-scoped bookmarks for fileURL (High)
**Files:** `Edison/Core/Models/ClipboardItem.swift`, any export/share call site in `AppState.swift`

**ClipboardPayload change:**
```swift
enum ClipboardPayload: Codable, Hashable {
    case text(String)
    case image(ClipboardImageData)
    case fileURL(Data)  // bookmark data instead of URL
}
```

**New helpers:**
- `static func bookmarkData(for url: URL) throws -> Data` — calls `url.bookmarkData(options: .withSecurityScope, ...)`
- `func resolvedURL() throws -> URL` — calls `URL(resolvingBookmarkData:options:.withSecurityScope, ...)`, then `startAccessingSecurityScopedResource()`
- Call `stopAccessingSecurityScopedResource()` after use (RAII wrapper or explicit call)

**Migration:** On decode, if a fileURL case fails to resolve as bookmark data (legacy raw-URL string), silently drop the item and log it at `.info`.

### Step 6 — Capture failure UX (High)
**Files:** `Edison/App/AppState.swift`, `Edison/Core/Capture/CaptureEngine.swift`

- Add `Notification.Name.edisonCaptureFailed` constant
- In `AppState`, subscribe to `edisonCaptureFailed` in `setupCapture()` or similar init path
- On receipt, set a `@Published var captureError: String?` property
- `HubView` or a floating banner shows the error with a "Open Screen Recording Settings" button:
  ```swift
  Button("Open Settings") {
      NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
  }
  ```

### Step 7 — Accessibility prompt for paste-back (Medium)
**File:** `Edison/App/AppState.swift` line 274

Replace:
```swift
guard AXIsProcessTrusted() else { return }
```
With:
```swift
let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
guard AXIsProcessTrustedWithOptions(opts) else {
    Log.permissions.info("Accessibility not granted; showing guidance banner")
    accessibilityDeniedOnce = true   // drives one-time Settings banner
    return
}
```
Add `@Published var accessibilityDeniedOnce = false` to `AppState`; `SettingsView` shows a one-time tip.

### Step 8 — HotKey registration error checking (Medium)
**File:** `Edison/Core/Shortcuts/HotKeyCenter.swift` lines 20–39

```swift
let status = RegisterEventHotKey(
    shortcut.keyCode, shortcut.modifiers,
    hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
)
guard status == noErr, hotKeyRef != nil else {
    Log.shortcuts.error("RegisterEventHotKey failed: \(status) for action \(action.rawValue)")
    failedRegistrations.append(action)
    continue
}
hotKeyRefs.append(hotKeyRef!)
bindings[hotKeyID.id] = action
```

Expose `failedRegistrations: [ShortcutAction]` so `SettingsView` can display "Shortcut unavailable — conflicts with another app."

### Step 9 — KeyRecorderField deinit guard (Medium)
**File:** `Edison/UI/Components/ShortcutEditorRow.swift` line 53+

Add to `KeyRecorderField`:
```swift
deinit {
    removeMonitor()
}
```
Where `removeMonitor()` is the existing method that removes the local event monitor. Confirm it is idempotent (nil-checks the monitor reference before removing).

### Step 10 — HistoryStore error logging (Medium)
**File:** `Edison/Core/Persistence/HistoryStore.swift` lines 39–46

Replace `try? data.write(...)` with:
```swift
do {
    try data.write(to: fileURL, options: .atomic)
} catch {
    Log.store.error("HistoryStore save failed: \(error.localizedDescription)")
}
```
Same pattern for `ShortcutStore.save` in `Edison/Core/Shortcuts/ShortcutStore.swift`.

### Step 11 — CI: Add Xcode scheme test job (Medium)
**File:** `.github/workflows/ci.yml`

Add a second job after the existing SwiftPM job:
```yaml
xcode-test:
  runs-on: macos-14
  timeout-minutes: 30
  steps:
    - uses: actions/checkout@v4
    - name: xcodebuild test
      run: |
        xcodebuild test \
          -project Edison.xcodeproj \
          -scheme "Edison - Clipboard Manager" \
          -destination "platform=macOS" \
          -configuration Debug \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO \
          | xcpretty || true
```

### Step 12 — Add governance files (Low)
Create in repo root:
- `LICENSE` — MIT, year 2025, copyright Chen Kahana
- `SECURITY.md` — vulnerability disclosure policy (GitHub Issues, response SLA 14 days)
- `CONTRIBUTING.md` — branch naming, PR checklist, style guide pointer

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Image migration breaks existing history | Keep old `ClipboardImageData` as a `LegacyClipboardImageData` Codable alias; migrate on first load; test with real history file |
| Security-scoped bookmarks fail for files user no longer has access to | Catch resolution errors, log at `.info`, silently drop the item from history |
| `AXIsProcessTrustedWithOptions` with prompt flag triggers TCC dialog at unexpected time | Gate the prompt call behind first actual paste attempt, not app launch |
| `xcodebuild test` in CI fails due to missing code signing | Pass `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` flags |
| 14.0 deployment target breaks a feature using newer API | Audit with `#available(macOS 14, *)` guards; annotate any newer-API callsites |

---

## Verification Steps

1. `swift build` — zero errors, zero warnings added
2. `swift test` — all existing tests pass
3. `xcodebuild test -project Edison.xcodeproj -scheme "Edison - Clipboard Manager" -destination "platform=macOS" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` — passes
4. Manual: copy an image to clipboard → history item shows thumbnail, `{AppSupport}/Edison/images/` contains the PNG files, `history.json` contains paths (not base64 blobs)
5. Manual: trigger screenshot capture with Screen Recording denied → in-app error banner appears within 1 second
6. Manual: trigger paste-back with Accessibility denied → system prompt appears (first time), Settings banner appears
7. Manual: set a shortcut that conflicts → Settings shows "Shortcut unavailable" message
8. `grep -r "MACOSX_DEPLOYMENT_TARGET" Edison.xcodeproj/project.pbxproj` → outputs `14.0` (no `26.3`)
9. Confirm `MARKETING_VERSION = 1.1` and `CURRENT_PROJECT_VERSION = 3` in `project.pbxproj`
10. `ls LICENSE SECURITY.md CONTRIBUTING.md` — all three exist in repo root

---

## Execution Order (dependency-aware)

```
Parallel batch A (no dependencies):
  ├── Step 2: Fix deployment target + bump build version
  ├── Step 9: KeyRecorderField deinit
  ├── Step 12: Add governance files

Step 3: Add OSLog Log.swift (needed by Steps 1, 8, 10)

Parallel batch B (depends on Step 3):
  ├── Step 1: Fix CaptureEngine retain-cycle + failure notification
  ├── Step 8: HotKey registration error checking
  └── Step 10: HistoryStore error logging

Step 4: Image store refactor (depends on Log.swift for error logging)
Step 5: Security-scoped bookmarks (after Step 4, shares ClipboardItem changes)

Parallel batch C (UI wiring, depends on Steps 1 and 7 groundwork):
  ├── Step 6: Capture failure UX in AppState + HubView
  └── Step 7: Accessibility prompt in AppState

Step 11: CI workflow (independent, but run after verifying xcodebuild command works locally)
```

---

## Files Changed Summary

| File | Change |
|---|---|
| `Edison/Core/Capture/CaptureEngine.swift` | Fix retain-cycle, add failure notification |
| `Edison/Core/Log.swift` | **New** — OSLog Logger definitions |
| `Edison/Core/Persistence/ImageStore.swift` | **New** — filesystem image storage |
| `Edison/Core/Models/ClipboardItem.swift` | Replace inline Data with paths + bookmark Data |
| `Edison/Core/Persistence/HistoryStore.swift` | Error logging, image migration on load |
| `Edison/Core/Shortcuts/HotKeyCenter.swift` | Check OSStatus, expose failures |
| `Edison/Core/Shortcuts/ShortcutStore.swift` | Error logging on encode |
| `Edison/App/AppState.swift` | AX prompt, capture failure subscription, error state |
| `Edison/UI/Components/ShortcutEditorRow.swift` | deinit on KeyRecorderField |
| `Edison/UI/Hub/HubView.swift` (or banner component) | Capture error banner UI |
| `Edison/UI/Settings/SettingsView.swift` | Shortcut conflict display, AX guidance |
| `Edison.xcodeproj/project.pbxproj` | Deployment target 14.0, build version 3 |
| `.github/workflows/ci.yml` | Add xcodebuild test job |
| `LICENSE` | **New** |
| `SECURITY.md` | **New** |
| `CONTRIBUTING.md` | **New** |
