import AppKit
import AudioToolbox
import Combine
import Foundation
import OSLog

// MARK: - CaptureCoordinator
//
// Owns capture/screenshot session state and coordinates the full lifecycle:
// capture -> session -> commit -> history + clipboard.
//
// Created and owned by AppState. AppState preserves its public API by
// delegating to this coordinator. The clipboard seam is explicit: two
// injected closures (addToHistory, suppressClipboardPayload) allow
// CaptureCoordinator to call back into ClipboardCoordinator through AppState
// without a direct dependency between the two coordinators.

@MainActor
final class CaptureCoordinator: ObservableObject {

    // MARK: - Published state

    @Published var activeScreenshotSession: ScreenshotSession?
    @Published var lastScreenshotSession: ScreenshotSession?
    @Published var captureError: String?
    @Published private(set) var screenRecordingAccessGranted: Bool
    @Published private(set) var lastCaptureFailureReason: String?
    /// Set once a capture was refused for lack of Screen Recording access. macOS only applies a grant
    /// made afterwards in System Settings once Edison relaunches, so Settings offers Quit & Reopen
    /// instead of claiming the grant alone fixed it.
    @Published private(set) var needsRelaunchForScreenRecording = false

    // MARK: - Dependencies

    private let captureEngine: CaptureEngine
    private let imageStore: ImageStore.Type
    private let messageHUD = MessageHUD()
    private var activationObserver: NSObjectProtocol?
    weak var windowRouter: WindowRouter?

    // MARK: - Injected closures

    /// Called when a screenshot becomes a ClipboardItem in history.
    var addToHistory: (ClipboardItem) -> Void

    /// Called when writing image data to the pasteboard so the clipboard
    /// monitor skips the re-ingestion of that payload.
    var suppressClipboardPayload: (ClipboardPayload) -> Void

    /// Called when the coordinator needs to look up an existing item in history
    /// (for in-place update during commit). Injected by AppState.
    var historyItems: () -> [ClipboardItem]

    /// Called to replace the full history slice (used for in-place image updates).
    var setHistoryItems: ([ClipboardItem]) -> Void

    /// Called to promote an item to front of history after in-place update.
    var promoteItemToFront: (UUID) -> Void

    /// Provides the current AppSettings (filename template, editor prefs, etc.)
    var currentSettings: () -> AppSettings

    /// Called when editor should be closed (delegates back to AppState).
    var closeEditor: () -> Void

    /// Called to present an NSAlert for errors.
    var presentError: (Error, String) -> Void

    /// Shows the floating thumbnail for a capture that went to history instead of the editor.
    var showThumbnail: (ScreenshotSession, Data, CGDirectDisplayID?) -> Void = { _, _, _ in }

    /// Called when the user asks for Screen Recording access: prompts and opens the System Settings pane.
    var requestScreenRecordingAccess: () -> Void

    // MARK: - Init

    init(
        captureEngine: CaptureEngine,
        imageStore: ImageStore.Type = ImageStore.self,
        windowRouter: WindowRouter?,
        addToHistory: @escaping (ClipboardItem) -> Void = { _ in },
        suppressClipboardPayload: @escaping (ClipboardPayload) -> Void = { _ in },
        historyItems: @escaping () -> [ClipboardItem] = { [] },
        setHistoryItems: @escaping ([ClipboardItem]) -> Void = { _ in },
        promoteItemToFront: @escaping (UUID) -> Void = { _ in },
        currentSettings: @escaping () -> AppSettings = { .default },
        closeEditor: @escaping () -> Void = {},
        presentError: @escaping (Error, String) -> Void = { _, _ in },
        requestScreenRecordingAccess: @escaping () -> Void = {}
    ) {
        self.captureEngine = captureEngine
        self.imageStore = imageStore
        self.windowRouter = windowRouter
        self.addToHistory = addToHistory
        self.suppressClipboardPayload = suppressClipboardPayload
        self.historyItems = historyItems
        self.setHistoryItems = setHistoryItems
        self.promoteItemToFront = promoteItemToFront
        self.currentSettings = currentSettings
        self.closeEditor = closeEditor
        self.presentError = presentError
        self.requestScreenRecordingAccess = requestScreenRecordingAccess
        self.screenRecordingAccessGranted = CGPreflightScreenCaptureAccess()

        // Catches a Screen Recording grant made in System Settings while Edison was in the background,
        // without waiting for the user to open Settings and press Refresh Status.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshPermissionStatuses()
            }
        }
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    // MARK: - Permission

    func refreshPermissionStatuses() {
        screenRecordingAccessGranted = CGPreflightScreenCaptureAccess()
    }

    /// Quits and relaunches Edison so a Screen Recording grant made after launch takes effect.
    func quitAndReopen() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in }
        NSApp.terminate(nil)
    }

    // MARK: - Capture

    var canCapturePreviousArea: Bool {
        captureEngine.previousArea(settings: currentSettings()) != nil
    }

    func startCapture(_ request: CaptureRequest) async {
        screenRecordingAccessGranted = CGPreflightScreenCaptureAccess()
        let result = await captureEngine.capture(request, settings: currentSettings())
        await handleCaptureResult(result)
    }

    func handleCaptureResult(_ result: CaptureResult) async {
        let settings = currentSettings()
        switch result {
        case let .success(data, displayID, rect):
            CaptureSound.play()
            captureError = nil
            lastCaptureFailureReason = nil
            let draft = ScreenshotDraft(
                baseImageData: data,
                fileNameHint: settings.defaultFileName(),
                captureDisplayID: displayID,
                captureRect: rect
            )
            let session = ScreenshotSession(draft: draft)

            let copies = settings.capture.defaultResult == .copyAndOpenEditor
            if settings.capture.openEditorAfterCapture {
                if copies {
                    persistAndCopy(session, copyToClipboard: true)
                }
                openEditor(for: session)
            } else {
                // Like ⇧⌘5: the capture goes to history (and the clipboard) and a thumbnail offers the editor.
                activeScreenshotSession = session
                commitScreenshotSession(session, copyToClipboard: copies)
                lastScreenshotSession = session.duplicateForEditing()
                windowRouter?.yieldFocusIfIdle()
                showThumbnail(session, data, displayID)
            }

        case .cancelled:
            captureError = nil
            windowRouter?.yieldFocusIfIdle()
        case .permissionDenied:
            screenRecordingAccessGranted = false
            needsRelaunchForScreenRecording = true
            lastCaptureFailureReason = "Screen Recording permission is required before Edison can capture screenshots."
            captureError = lastCaptureFailureReason
            presentScreenRecordingPermissionPrompt()
        case let .failure(reason):
            lastCaptureFailureReason = reason
            captureError = reason
            Log.capture.error("Capture failed – \(reason)")
            // Capture often starts from a hotkey with the Hub closed, so the failure must surface on
            // its own rather than wait inside a window nobody has open.
            messageHUD.show(message: reason)
        }
    }

    func openEditor(for session: ScreenshotSession) {
        activeScreenshotSession = session
        lastScreenshotSession = session.duplicateForEditing()
        windowRouter?.openEditor()
    }

    func commitScreenshotSession(_ session: ScreenshotSession, copyToClipboard: Bool) {
        guard persistAndCopy(session, copyToClipboard: copyToClipboard) else { return }
        if currentSettings().editor.closeAfterCopySave {
            closeEditor()
        }
    }

    @discardableResult
    private func persistAndCopy(_ session: ScreenshotSession, copyToClipboard: Bool) -> Bool {
        do {
            let pngData = try session.renderedPNGData()
            let item = try persistScreenshotImage(pngData, existingItemID: session.committedItemID)
            session.recordCommit(itemID: item.id)
            lastScreenshotSession = session.duplicateForEditing()

            if copyToClipboard {
                writeImageDataToClipboard(pngData, payload: item.payload)
            }
            return true
        } catch {
            presentError(error, "Screenshot Commit Failed")
            return false
        }
    }

    private func persistScreenshotImage(_ data: Data, existingItemID: UUID?) throws -> ClipboardItem {
        guard let prepared = ImageProcessing.prepareImagePayload(from: data, id: existingItemID ?? UUID()) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let items = historyItems()
        if let existingItemID,
           let index = items.firstIndex(where: { $0.id == existingItemID }) {
            let oldItem = items[index]
            if case let .image(oldImage) = oldItem.payload {
                imageStore.delete(relativePath: oldImage.imagePath)
                imageStore.delete(relativePath: oldImage.thumbnailPath)
            }

            var updated = items
            updated[index] = ClipboardItem(
                id: existingItemID,
                createdAt: .now,
                isFavorite: oldItem.isFavorite,
                sourceApplication: oldItem.sourceApplication,
                payload: .image(prepared)
            )
            setHistoryItems(updated)
            promoteItemToFront(existingItemID)
            let current = historyItems()
            return current.first(where: { $0.id == existingItemID }) ?? current[0]
        }

        let item = ClipboardItem(payload: .image(prepared))
        addToHistory(item)
        return item
    }

    private func writeImageDataToClipboard(_ data: Data, payload: ClipboardPayload) {
        suppressClipboardPayload(payload)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        _ = pasteboard.setData(data, forType: .png)
    }

    /// A floating prompt, not `NSAlert.runModal()`: this fires from a hotkey while another app is
    /// active, and a modal alert can open behind that app and block the run loop until answered.
    private func presentScreenRecordingPermissionPrompt() {
        let action: HubMessageBanner.Action = needsRelaunchForScreenRecording && screenRecordingAccessGranted
            ? HubMessageBanner.Action(title: "Quit & Reopen Edison", handler: { [weak self] in self?.quitAndReopen() })
            : HubMessageBanner.Action(title: "Open System Settings", handler: { [weak self] in self?.requestScreenRecordingAccess() })
        messageHUD.show(
            message: "Edison needs Screen Recording access to capture screenshots.",
            actions: [action]
        )
    }
}

/// The macOS screenshot sound. Played as a UI sound, so it follows "Play user interface sound effects".
private enum CaptureSound {
    private static let soundID: SystemSoundID? = {
        let url = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif")
        var soundID: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &soundID) == kAudioServicesNoError else { return nil }
        return soundID
    }()

    static func play() {
        if let soundID {
            AudioServicesPlaySystemSound(soundID)
        }
    }
}
