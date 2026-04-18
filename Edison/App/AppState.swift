import AppKit
import Combine
import Foundation
import OSLog
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    private enum HistorySource {
        case clipboard
        case internalAction
    }

    @Published var activeQuery = ""
    @Published var selectedTypeFilter: HistoryItemTypeFilter = .all
    @Published private(set) var historyItems: [ClipboardItem] = []
    @Published private(set) var collections: [ItemCollection] = []
    @Published var selectedCollectionID: UUID?
    @Published private(set) var settings: AppSettings
    @Published private(set) var activeScreenshotSession: ScreenshotSession?
    @Published private(set) var lastScreenshotSession: ScreenshotSession?
    @Published var showEditorDiscardAlert = false
    @Published private(set) var deletedItemForUndo: ClipboardItem?
    @Published private(set) var showDeleteUndoToast = false
    @Published var captureError: String?
    @Published private(set) var accessibilityDenied = false
    @Published private(set) var failedShortcutActions: [ShortcutAction] = []
    @Published private(set) var screenRecordingAccessGranted: Bool
    @Published private(set) var lastCaptureFailureReason: String?
    @Published private(set) var launchAtLoginStatusDescription = "Unavailable"
    @Published private(set) var launchAtLoginErrorMessage: String?

    let shortcutStore = ShortcutStore()
    let settingsStore = SettingsStore()
    let hotKeyCenter = HotKeyCenter.shared
    let captureEngine = CaptureEngine()

    private let historyStore = HistoryStore()
    private let clipboardMonitor = ClipboardMonitor()
    private let launchAtLoginController = LaunchAtLoginController()
    private let searchEngine = HistorySearchEngine()
    private let missingWindowError = NSError(
        domain: "Edison.Share",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "No active window available for sharing."]
    )

    private let enableRuntimeServices: Bool
    private let frontmostApplicationProvider: () -> NSRunningApplication?
    private let pasteBackCoordinatorOverride: PasteBackCoordinator?
    private let accessibilityPromptRequester: () -> Void
    private let accessibilitySettingsOpener: () -> Void
    private let screenRecordingSettingsOpener: () -> Void
    private var suppressedClipboardPayloads = Set<ClipboardPayload>()
    private var undoTimer: Timer?
    private lazy var pasteBackCoordinator = pasteBackCoordinatorOverride ?? makePasteBackCoordinator()

    weak var windowRouter: WindowRouter?
    private(set) var lastActiveApp: NSRunningApplication?
    private var pasteBackTargetApp: NSRunningApplication?
    private(set) var isPasteInFlight = false
    private var activeAppObserver: NSObjectProtocol?
    private var shortcutActionRequestObserver: NSObjectProtocol?

    var filteredItems: [ClipboardItem] {
        return Log.performance.withIntervalSignpost("Search Filter") {
            let searched = searchEngine.filter(
                query: activeQuery,
                in: historyItems,
                type: selectedTypeFilter
            )
            guard let selectedCollectionID,
                  let collection = collections.first(where: { $0.id == selectedCollectionID }) else {
                return searched
            }

            let itemIDs = Set(collection.itemIDs)
            return searched.filter { itemIDs.contains($0.id) }
        }
    }

    var favoriteItems: [ClipboardItem] {
        filteredItems.filter(\.isFavorite)
    }

    init(
        enableRuntimeServices: Bool = true,
        frontmostApplicationProvider: @escaping () -> NSRunningApplication? = { NSWorkspace.shared.frontmostApplication },
        pasteBackCoordinatorOverride: PasteBackCoordinator? = nil,
        initialLastActiveApp: NSRunningApplication? = nil,
        accessibilityPromptRequester: (() -> Void)? = nil,
        accessibilitySettingsOpener: (() -> Void)? = nil,
        screenRecordingSettingsOpener: (() -> Void)? = nil
    ) {
        self.enableRuntimeServices = enableRuntimeServices
        self.frontmostApplicationProvider = frontmostApplicationProvider
        self.pasteBackCoordinatorOverride = pasteBackCoordinatorOverride
        self.lastActiveApp = initialLastActiveApp
        self.settings = settingsStore.current
        self.screenRecordingAccessGranted = CGPreflightScreenCaptureAccess()
        self.accessibilityPromptRequester = accessibilityPromptRequester ?? {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
            // The dialog is asynchronous — re-check on next paste attempt via AXIsProcessTrusted().
        }
        self.accessibilitySettingsOpener = accessibilitySettingsOpener ?? {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
                return
            }
            NSWorkspace.shared.open(url)
        }
        self.screenRecordingSettingsOpener = screenRecordingSettingsOpener ?? {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
                return
            }
            NSWorkspace.shared.open(url)
        }

        refreshLaunchAtLoginStatus()

        guard enableRuntimeServices else { return }

        historyStore.loadAsync { [weak self] loadedItems, loadedCollections in
            Task { @MainActor in
                self?.historyItems = loadedItems
                self?.collections = loadedCollections
            }
        }

        hotKeyCenter.updateHandler { [weak self] action in
            Task { @MainActor in
                self?.handle(hotKeyAction: action)
            }
        }
        hotKeyCenter.apply(shortcuts: shortcutStore.current)
        failedShortcutActions = hotKeyCenter.failedRegistrations

        clipboardMonitor.start { [weak self] newItem in
            Task { @MainActor in
                self?.addToHistory(newItem)
            }
        }

        shortcutActionRequestObserver = NotificationCenter.default.addObserver(
            forName: .edisonShortcutActionRequested,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let rawValue = note.object as? String,
                  let action = ShortcutAction(rawValue: rawValue) else { return }

            MainActor.assumeIsolated {
                self?.perform(action: action)
            }
        }

        activeAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            MainActor.assumeIsolated {
                self?.lastActiveApp = app
            }
        }
    }

    deinit {
        let clipboardMonitor = clipboardMonitor
        let activeAppObserver = activeAppObserver
        let shortcutActionRequestObserver = shortcutActionRequestObserver
        Task { @MainActor in
            clipboardMonitor.stop()
            if let shortcutActionRequestObserver {
                NotificationCenter.default.removeObserver(shortcutActionRequestObserver)
            }
            if let activeAppObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(activeAppObserver)
            }
        }
    }

    func handle(hotKeyAction: ShortcutAction) {
        perform(action: hotKeyAction)
    }

    /// Triggers the macOS system accessibility permission prompt.
    /// Call from a user-initiated action (e.g., Settings button) — not from the paste hot path.
    func requestAccessibilityAccess() {
        accessibilityPromptRequester()
        accessibilitySettingsOpener()
    }

    func requestScreenRecordingAccess() {
        _ = captureEngine.requestScreenRecordingPermission()
        screenRecordingSettingsOpener()
        refreshPermissionStatuses()
    }

    func refreshPermissionStatuses() {
        screenRecordingAccessGranted = CGPreflightScreenCaptureAccess()
    }

    private func perform(action: ShortcutAction) {
        switch action {
        case .openHub:
            toggleHubFromShortcut()
        case .captureScreenshot:
            Task { await startCapture(.screenshot) }
        case .captureWindow:
            Task { await startCapture(.window) }
        case .captureFullScreen:
            Task { await startCapture(.fullScreen) }
        case .capturePreviousArea:
            Task { await startCapture(.previousArea) }
        case .editLastScreenshot:
            editLastScreenshot()
        case .openSettings:
            windowRouter?.openSettings()
        }
    }

    func save(shortcuts: ShortcutSet) {
        shortcutStore.save(shortcuts)
        hotKeyCenter.apply(shortcuts: shortcuts)
        failedShortcutActions = hotKeyCenter.failedRegistrations
    }

    func save(settings: AppSettings) {
        self.settings = settings
        settingsStore.save(settings)
        refreshLaunchAtLogin(settings.general.launchAtLogin)
        trimHistoryToSettingsLimit()
    }

    func restoreDefaultSettings() {
        save(settings: .default)
    }

    func createCollection(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !collections.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }

        let collection = ItemCollection(name: trimmed)
        collections.insert(collection, at: 0)
        selectedCollectionID = collection.id
        persistHistory()
    }

    func deleteCollection(id: UUID) {
        collections.removeAll { $0.id == id }
        if selectedCollectionID == id {
            selectedCollectionID = nil
        }
        persistHistory()
    }

    func addItem(_ itemID: UUID, toCollection collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        guard !collections[index].itemIDs.contains(itemID) else { return }

        collections[index].itemIDs.insert(itemID, at: 0)
        persistHistory()
    }

    func removeItem(_ itemID: UUID, fromCollection collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }

        collections[index].itemIDs.removeAll { $0 == itemID }
        persistHistory()
    }

    func toggleItem(_ itemID: UUID, inCollection collectionID: UUID) {
        guard let collection = collections.first(where: { $0.id == collectionID }) else { return }
        if collection.itemIDs.contains(itemID) {
            removeItem(itemID, fromCollection: collectionID)
        } else {
            addItem(itemID, toCollection: collectionID)
        }
    }

    func collectionContains(_ itemID: UUID, collectionID: UUID) -> Bool {
        collections
            .first(where: { $0.id == collectionID })?
            .itemIDs
            .contains(itemID) ?? false
    }

    func toggleFavorite(itemID: UUID) {
        guard let index = historyItems.firstIndex(where: { $0.id == itemID }) else { return }
        historyItems[index].isFavorite.toggle()
        persistHistory()
    }

    func deleteItem(itemID: UUID) {
        guard let index = historyItems.firstIndex(where: { $0.id == itemID }) else { return }
        let item = historyItems[index]

        historyItems.remove(at: index)
        for idx in collections.indices {
            collections[idx].itemIDs.removeAll { $0 == itemID }
        }
        persistHistory()

        deletedItemForUndo = item
        showDeleteUndoToast = true
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Undo window expired — now safe to remove image files from disk.
                // Capture `item` at scheduling time so a subsequent delete doesn't
                // overwrite `deletedItemForUndo` before this timer fires.
                if case let .image(imageData) = item.payload {
                    ImageStore.delete(relativePath: imageData.imagePath)
                    ImageStore.delete(relativePath: imageData.thumbnailPath)
                }
                self?.showDeleteUndoToast = false
                self?.deletedItemForUndo = nil
            }
        }
    }

    func undoDelete() {
        guard let item = deletedItemForUndo else { return }
        undoTimer?.invalidate()
        undoTimer = nil
        historyItems.insert(item, at: 0)
        persistHistory()
        deletedItemForUndo = nil
        showDeleteUndoToast = false
    }

    func copyToClipboard(itemID: UUID) {
        guard let item = historyItems.first(where: { $0.id == itemID }) else { return }
        _ = writeItemToClipboard(item)
    }

    func pasteItem(itemID: UUID) {
        guard let item = historyItems.first(where: { $0.id == itemID }) else { return }
        pasteResolvedItem(item)
    }

    func pasteSelection(from items: [ClipboardItem], selectedItemID: UUID?) {
        guard let item = PasteSelectionResolver.resolve(from: items, selectedItemID: selectedItemID) else { return }
        pasteResolvedItem(item)
    }

    func dismissHub() {
        guard !isPasteInFlight else { return }
        clearPasteBackContext()
        windowRouter?.dismissHub()
    }

    private func promoteItemToFront(itemID: UUID) {
        guard let index = historyItems.firstIndex(where: { $0.id == itemID }) else { return }

        var item = historyItems.remove(at: index)
        item.createdAt = .now
        historyItems.insert(item, at: 0)
        persistHistory()
    }

    func exportItem(itemID: UUID) {
        guard let item = historyItems.first(where: { $0.id == itemID }) else { return }
        do {
            let export = try makeExportPayload(for: item)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = export.defaultFileName
            panel.allowedContentTypes = [export.contentType]
            panel.canCreateDirectories = true

            if let window = NSApp.keyWindow {
                panel.beginSheetModal(for: window) { [weak self] response in
                    guard response == .OK, let url = panel.url else { return }
                    self?.writeExportPayload(export, to: url)
                }
            } else if panel.runModal() == .OK, let url = panel.url {
                writeExportPayload(export, to: url)
            }
        } catch {
            present(error: error, title: "Export Failed")
        }
    }

    func shareItem(itemID: UUID) {
        guard let item = historyItems.first(where: { $0.id == itemID }) else { return }
        do {
            let shareItems = try makeShareItems(for: item)
            let picker = NSSharingServicePicker(items: shareItems)
            guard let contentView = NSApp.keyWindow?.contentView else {
                throw missingWindowError
            }

            let anchor = NSRect(
                x: contentView.bounds.midX,
                y: contentView.bounds.midY,
                width: 1,
                height: 1
            )
            picker.show(relativeTo: anchor, of: contentView, preferredEdge: .minY)
        } catch {
            present(error: error, title: "Share Failed")
        }
    }

    func requestEditorClose() {
        guard let activeScreenshotSession else {
            closeEditorImmediately()
            return
        }
        if activeScreenshotSession.hasUnsavedChanges {
            showEditorDiscardAlert = true
            return
        }
        lastScreenshotSession = activeScreenshotSession.duplicateForEditing()
        closeEditorImmediately()
    }

    func discardAndCloseEditor() {
        if let activeScreenshotSession {
            lastScreenshotSession = activeScreenshotSession.duplicateForEditing()
        }
        showEditorDiscardAlert = false
        closeEditorImmediately()
    }

    func closeEditorImmediately() {
        showEditorDiscardAlert = false
        windowRouter?.dismissEditor()
        activeScreenshotSession = nil
    }

    func editLastScreenshot() {
        guard let lastScreenshotSession else {
            captureError = "There is no previous screenshot to edit yet."
            return
        }
        openEditor(with: lastScreenshotSession.duplicateForEditing())
    }

    func keepActiveScreenshot() {
        guard let activeScreenshotSession else { return }
        commitScreenshotSession(activeScreenshotSession, copyToClipboard: false)
    }

    func copyActiveScreenshot() {
        guard let activeScreenshotSession else { return }
        commitScreenshotSession(activeScreenshotSession, copyToClipboard: true)
    }

    func saveActiveScreenshot() {
        guard let activeScreenshotSession else { return }
        do {
            let png = try activeScreenshotSession.renderedPNGData()
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.png]
            panel.nameFieldStringValue = "\(settings.defaultFileName()).png"
            if let defaultSaveFolderPath = settings.capture.defaultSaveFolderPath {
                panel.directoryURL = URL(fileURLWithPath: defaultSaveFolderPath, isDirectory: true)
            }

            guard panel.runModal() == .OK, let url = panel.url else { return }
            try png.write(to: url, options: .atomic)
            commitScreenshotSession(activeScreenshotSession, copyToClipboard: false)
        } catch {
            present(error: error, title: "Save Failed")
        }
    }

    func clearHistory() {
        historyItems.forEach { item in
            if case let .image(imageData) = item.payload {
                ImageStore.delete(relativePath: imageData.imagePath)
                ImageStore.delete(relativePath: imageData.thumbnailPath)
            }
        }
        historyItems.removeAll()
        collections.removeAll()
        selectedCollectionID = nil
        persistHistory()
    }

    func revealStorageFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([HistoryStore.storageDirectory])
    }

    func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "edison-diagnostics.txt"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let diagnostics = """
        Edison Diagnostics
        Generated: \(ISO8601DateFormatter().string(from: .now))
        Screen Recording Access: \(screenRecordingAccessGranted)
        Accessibility Access: \(AXIsProcessTrusted())
        Failed Shortcuts: \(failedShortcutActions.map(\.title).joined(separator: ", "))
        History Count: \(historyItems.count)
        Collections Count: \(collections.count)
        Last Capture Failure: \(lastCaptureFailureReason ?? "None")
        Launch At Login: \(launchAtLoginStatusDescription)
        Settings: \(String(describing: settings))
        """

        do {
            try diagnostics.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            present(error: error, title: "Diagnostics Export Failed")
        }
    }

    private func addToHistory(_ item: ClipboardItem, source: HistorySource = .clipboard) {
        if source == .clipboard, suppressedClipboardPayloads.remove(item.payload) != nil {
            return
        }

        historyItems.removeAll { $0.payload == item.payload }
        historyItems.insert(item, at: 0)

        if historyItems.count > settings.privacy.historyLimit {
            let excess = historyItems.suffix(historyItems.count - settings.privacy.historyLimit)
            for pruned in excess {
                if case let .image(imageData) = pruned.payload {
                    ImageStore.delete(relativePath: imageData.imagePath)
                    ImageStore.delete(relativePath: imageData.thumbnailPath)
                }
            }
            historyItems.removeLast(historyItems.count - settings.privacy.historyLimit)
        }

        let liveItemIDs = Set(historyItems.map(\.id))
        for index in collections.indices {
            collections[index].itemIDs.removeAll { !liveItemIDs.contains($0) }
        }

        persistHistory()
    }

    private func persistHistory() {
        historyStore.save(items: historyItems, collections: collections)
    }

    private func trimHistoryToSettingsLimit() {
        guard historyItems.count > settings.privacy.historyLimit else { return }
        let excess = historyItems.suffix(historyItems.count - settings.privacy.historyLimit)
        for pruned in excess {
            if case let .image(imageData) = pruned.payload {
                ImageStore.delete(relativePath: imageData.imagePath)
                ImageStore.delete(relativePath: imageData.thumbnailPath)
            }
        }
        historyItems.removeLast(historyItems.count - settings.privacy.historyLimit)
        persistHistory()
    }

    private func refreshLaunchAtLogin(_ isEnabled: Bool) {
        launchAtLoginController.setEnabled(isEnabled)
        launchAtLoginErrorMessage = launchAtLoginController.lastErrorMessage
        refreshLaunchAtLoginStatus()
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginController.refreshStatus()
        launchAtLoginErrorMessage = launchAtLoginController.lastErrorMessage
        launchAtLoginStatusDescription = launchAtLoginController.statusDescription
    }

    private func toggleHubFromShortcut() {
        let signposter = Log.performance
        let state = signposter.beginInterval("Hub Toggle")
        defer { signposter.endInterval("Hub Toggle", state) }

        guard let windowRouter else { return }

        if windowRouter.isHubPresented {
            dismissHub()
        } else {
            capturePasteBackTargetApp()
            windowRouter.openHub()
        }
    }

    private func capturePasteBackTargetApp() {
        let frontmostApplication = frontmostApplicationProvider()
        if let frontmostApplication,
           frontmostApplication.bundleIdentifier != Bundle.main.bundleIdentifier {
            pasteBackTargetApp = frontmostApplication
        } else {
            pasteBackTargetApp = lastActiveApp
        }
    }

    private func clearPasteBackContext() {
        pasteBackTargetApp = nil
    }

    private func pasteResolvedItem(_ item: ClipboardItem) {
        guard !isPasteInFlight else { return }

        isPasteInFlight = true
        accessibilityDenied = false
        let targetApp = pasteBackTargetApp ?? lastActiveApp

        pasteBackCoordinator.run(
            item: item,
            targetApp: targetApp,
            onAccessibilityDenied: { [weak self] in
                self?.handleAccessibilityDeniedForPasteBack()
            },
            completion: { [weak self] in
                self?.finishPasteBack()
            }
        )
    }

    private func finishPasteBack() {
        isPasteInFlight = false
        clearPasteBackContext()
    }

    private func handleAccessibilityDeniedForPasteBack() {
        Log.permissions.info("Accessibility not granted; paste-back unavailable")
        accessibilityDenied = true
    }

    @discardableResult
    private func writeItemToClipboard(_ item: ClipboardItem) -> Bool {
        suppressedClipboardPayloads.insert(item.payload)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let wroteToPasteboard: Bool

        switch item.payload {
        case let .text(value):
            wroteToPasteboard = pasteboard.setString(value, forType: .string)
        case let .image(image):
            if let data = try? ImageStore.load(relativePath: image.imagePath) {
                wroteToPasteboard = pasteboard.setData(data, forType: .png)
            } else {
                wroteToPasteboard = false
            }
        case let .fileURL(url):
            wroteToPasteboard = pasteboard.writeObjects([url as NSURL])
        }

        if wroteToPasteboard {
            promoteItemToFront(itemID: item.id)
        }

        return wroteToPasteboard
    }

    private func makePasteBackCoordinator() -> PasteBackCoordinator {
        PasteBackCoordinator(
            writeItemToClipboard: { [weak self] item in
                self?.writeItemToClipboard(item) ?? false
            },
            closeHub: { [weak self] in
                self?.windowRouter?.dismissHubForPasteBack()
            }
        )
    }

    private func startCapture(_ request: CaptureRequest) async {
        refreshPermissionStatuses()
        let result = await captureEngine.capture(request, settings: settings)
        await handleCaptureResult(result)
    }

    private func handleCaptureResult(_ result: CaptureResult) async {
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
                openEditor(with: session)
            } else {
                activeScreenshotSession = session
                keepActiveScreenshot()
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

    private func openEditor(with session: ScreenshotSession) {
        activeScreenshotSession = session
        lastScreenshotSession = session.duplicateForEditing()
        windowRouter?.openEditor()
    }

    private func commitScreenshotSession(_ session: ScreenshotSession, copyToClipboard: Bool) {
        do {
            let pngData = try session.renderedPNGData()
            let item = try persistScreenshotImage(pngData, existingItemID: session.committedItemID)
            session.recordCommit(itemID: item.id)
            lastScreenshotSession = session.duplicateForEditing()

            if copyToClipboard {
                writeImageDataToClipboard(pngData, payload: item.payload)
            }

            if settings.editor.closeAfterCopySave {
                closeEditorImmediately()
            }
        } catch {
            present(error: error, title: "Screenshot Commit Failed")
        }
    }

    private func persistScreenshotImage(_ data: Data, existingItemID: UUID?) throws -> ClipboardItem {
        guard let prepared = ImageProcessing.prepareImagePayload(from: data, id: existingItemID ?? UUID()) else {
            throw CocoaError(.fileWriteUnknown)
        }

        if let existingItemID,
           let index = historyItems.firstIndex(where: { $0.id == existingItemID }) {
            let oldItem = historyItems[index]
            if case let .image(oldImage) = oldItem.payload {
                ImageStore.delete(relativePath: oldImage.imagePath)
                ImageStore.delete(relativePath: oldImage.thumbnailPath)
            }

            historyItems[index] = ClipboardItem(
                id: existingItemID,
                createdAt: .now,
                isFavorite: oldItem.isFavorite,
                sourceApplication: oldItem.sourceApplication,
                payload: .image(prepared)
            )
            promoteItemToFront(itemID: existingItemID)
            return historyItems.first(where: { $0.id == existingItemID }) ?? historyItems[0]
        }

        let item = ClipboardItem(payload: .image(prepared))
        addToHistory(item, source: .internalAction)
        return item
    }

    private func writeImageDataToClipboard(_ data: Data, payload: ClipboardPayload) {
        suppressedClipboardPayloads.insert(payload)
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
            requestScreenRecordingAccess()
        }
    }

    private func makeExportPayload(
        for item: ClipboardItem
    ) throws -> (data: Data, defaultFileName: String, contentType: UTType) {
        switch item.payload {
        case let .text(value):
            guard let data = value.data(using: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            return (data, "edison-export.txt", .plainText)
        case let .image(image):
            let data = try ImageStore.load(relativePath: image.imagePath)
            return (data, "edison-image.png", .png)
        case let .fileURL(url):
            let data = try Data(contentsOf: url)
            let filename = url.lastPathComponent.isEmpty ? "edison-file" : url.lastPathComponent
            let contentType = UTType(filenameExtension: url.pathExtension) ?? .data
            return (data, filename, contentType)
        }
    }

    private func writeExportPayload(
        _ payload: (data: Data, defaultFileName: String, contentType: UTType),
        to url: URL
    ) {
        do {
            try payload.data.write(to: url, options: .atomic)
        } catch {
            present(error: error, title: "Export Failed")
        }
    }

    private func makeShareItems(for item: ClipboardItem) throws -> [Any] {
        switch item.payload {
        case let .text(value):
            return [value]
        case let .image(image):
            let data = try ImageStore.load(relativePath: image.imagePath)
            guard let nsImage = NSImage(data: data) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return [nsImage]
        case let .fileURL(url):
            return [url]
        }
    }

    private func present(error: Error, title: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

extension Notification.Name {
    static let edisonScreenshotCaptured = Notification.Name("edison.screenshot.captured")
    static let edisonShortcutActionRequested = Notification.Name("edison.shortcut-action.requested")
    static let edisonCaptureFailed = Notification.Name("edison.capture.failed")
}
