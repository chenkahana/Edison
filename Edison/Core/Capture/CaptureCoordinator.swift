import AppKit
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

    // MARK: - Dependencies

    private let captureEngine: CaptureEngine
    private let imageStore: ImageStore.Type
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
        presentError: @escaping (Error, String) -> Void = { _, _ in }
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
        self.screenRecordingAccessGranted = CGPreflightScreenCaptureAccess()
    }

    // MARK: - Permission

    func refreshPermissionStatuses() {
        screenRecordingAccessGranted = CGPreflightScreenCaptureAccess()
    }

    // MARK: - Capture

    func startCapture(_ request: CaptureRequest) async {
        screenRecordingAccessGranted = CGPreflightScreenCaptureAccess()
        let result = await captureEngine.capture(request, settings: currentSettings())
        await handleCaptureResult(result)
    }

    func handleCaptureResult(_ result: CaptureResult) async {
        let settings = currentSettings()
        switch result {
        case let .success(data, displayID, rect):
            captureError = nil
            lastCaptureFailureReason = nil
            let draft = ScreenshotDraft(
                baseImageData: data,
                fileNameHint: settings.defaultFileName(),
                captureDisplayID: displayID,
                captureRect: rect
            )
            let session = ScreenshotSession(draft: draft)

            if settings.capture.openEditorAfterCapture || settings.capture.defaultResult != .keepInHistory {
                openEditor(for: session)
            } else {
                activeScreenshotSession = session
                commitScreenshotSession(session, copyToClipboard: false)
            }

        case .cancelled:
            captureError = nil
        case .permissionDenied:
            screenRecordingAccessGranted = false
            lastCaptureFailureReason = "Screen Recording permission is required before Edison can capture screenshots."
            captureError = lastCaptureFailureReason
            presentScreenRecordingPermissionAlert()
        case let .failure(reason):
            lastCaptureFailureReason = reason
            captureError = reason
            Log.capture.error("Capture failed – \(reason)")
        }
    }

    func openEditor(for session: ScreenshotSession) {
        activeScreenshotSession = session
        lastScreenshotSession = session.duplicateForEditing()
        windowRouter?.openEditor()
    }

    func commitScreenshotSession(_ session: ScreenshotSession, copyToClipboard: Bool) {
        do {
            let pngData = try session.renderedPNGData()
            let item = try persistScreenshotImage(pngData, existingItemID: session.committedItemID)
            session.recordCommit(itemID: item.id)
            lastScreenshotSession = session.duplicateForEditing()

            if copyToClipboard {
                writeImageDataToClipboard(pngData, payload: item.payload)
            }

            if currentSettings().editor.closeAfterCopySave {
                closeEditor()
            }
        } catch {
            presentError(error, "Screenshot Commit Failed")
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

    private func presentScreenRecordingPermissionAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Allow Screen Recording"
        alert.informativeText = "Edison needs Screen Recording access to capture screenshots. Open System Settings and enable Edison under Privacy & Security > Screen Recording."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn {
            _ = captureEngine.requestScreenRecordingPermission()
            screenRecordingAccessGranted = CGPreflightScreenCaptureAccess()
        }
    }
}
