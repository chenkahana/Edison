import AppKit
import Combine
import Foundation
import OSLog
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {

    // MARK: - Delegated clipboard/history state

    /// The coordinator owns historyItems, deletedItemForUndo, showDeleteUndoToast,
    /// and suppressedClipboardPayloads. AppState re-emits coordinator's objectWillChange
    /// so existing view bindings (which observe AppState) continue to trigger re-renders.
    private let clipboardCoordinator: ClipboardCoordinator
    private var coordinatorCancellable: AnyCancellable?

    // MARK: - Delegated capture state

    /// The coordinator owns screenshot session state, capture errors, and screen recording
    /// permission. AppState re-emits its objectWillChange so view bindings remain live.
    private(set) var captureCoordinator: CaptureCoordinator
    private var captureCoordinatorCancellable: AnyCancellable?

    // MARK: - Published properties owned by AppState

    @Published var activeQuery = ""
    @Published var selectedTypeFilter: HistoryItemTypeFilter = .all
    @Published private(set) var collections: [ItemCollection] = []
    @Published var selectedCollectionID: UUID?
    @Published private(set) var settings: AppSettings
    @Published var showEditorDiscardAlert = false
    @Published private(set) var accessibilityDenied = false
    @Published private(set) var failedShortcutActions: [ShortcutAction] = []
    @Published private(set) var launchAtLoginStatusDescription = "Unavailable"
    @Published private(set) var launchAtLoginErrorMessage: String?

    // MARK: - Public API that delegates to ClipboardCoordinator

    var historyItems: [ClipboardItem] { clipboardCoordinator.historyItems }
    var deletedItemForUndo: ClipboardItem? { clipboardCoordinator.deletedItemForUndo }
    var showDeleteUndoToast: Bool { clipboardCoordinator.showDeleteUndoToast }

    // MARK: - Public API that delegates to CaptureCoordinator

    var activeScreenshotSession: ScreenshotSession? { captureCoordinator.activeScreenshotSession }
    var lastScreenshotSession: ScreenshotSession? { captureCoordinator.lastScreenshotSession }
    var captureError: String? {
        get { captureCoordinator.captureError }
        set { captureCoordinator.captureError = newValue }
    }
    var screenRecordingAccessGranted: Bool { captureCoordinator.screenRecordingAccessGranted }
    var lastCaptureFailureReason: String? { captureCoordinator.lastCaptureFailureReason }

    // MARK: - View-model computed properties (stay in AppState)

    var filteredItems: [ClipboardItem] {
        return Log.performance.withIntervalSignpost("Search Filter") {
            let searched = searchEngine.filter(
                query: activeQuery,
                in: clipboardCoordinator.historyItems,
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

    // MARK: - Services

    let shortcutStore = ShortcutStore()
    let settingsStore = SettingsStore()
    let hotKeyCenter = HotKeyCenter.shared
    let captureEngine = CaptureEngine()  // retained here for requestScreenRecordingAccess

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
    private lazy var pasteBackCoordinator = pasteBackCoordinatorOverride ?? makePasteBackCoordinator()

    weak var windowRouter: WindowRouter? {
        didSet { captureCoordinator.windowRouter = windowRouter }
    }
    private(set) var lastActiveApp: NSRunningApplication?
    private var pasteBackTargetApp: NSRunningApplication?
    private(set) var isPasteInFlight = false
    private var activeAppObserver: NSObjectProtocol?
    private var shortcutActionRequestObserver: NSObjectProtocol?

    // MARK: - Init

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

        // Build coordinators. Both must be assigned before any self-referencing closures
        // so Swift's definite initialization is satisfied.
        let coordinator = ClipboardCoordinator(
            historyStore: historyStore,
            clipboardMonitor: clipboardMonitor
        )
        self.clipboardCoordinator = coordinator

        // CaptureCoordinator is initialized with placeholder closures here; the real
        // closures are wired below after `self` is fully initialized.
        self.captureCoordinator = CaptureCoordinator(
            captureEngine: captureEngine,
            windowRouter: nil  // windowRouter is set externally after init
        )

        // All stored properties are now initialized — `self` is safe to use.

        refreshLaunchAtLoginStatus()

        // Wire clipboard coordinator callbacks.
        coordinator.historyLimit = { [weak self] in
            self?.settings.privacy.historyLimit ?? 500
        }
        coordinator.onHistoryChanged = { [weak self] liveItemIDs in
            guard let self else { return }
            for index in self.collections.indices {
                self.collections[index].itemIDs.removeAll { !liveItemIDs.contains($0) }
            }
        }
        coordinator.onPersistRequested = { [weak self] in
            guard let self else { return }
            self.historyStore.save(items: self.clipboardCoordinator.historyItems, collections: self.collections)
        }
        coordinator.onItemDeleted = { [weak self] itemID in
            guard let self else { return }
            for idx in self.collections.indices {
                self.collections[idx].itemIDs.removeAll { $0 == itemID }
            }
        }

        // Wire capture coordinator closures (closures reference self, safe now).
        captureCoordinator.addToHistory = { [weak self] item in
            self?.clipboardCoordinator.addToHistory(item, source: .internalAction)
        }
        captureCoordinator.suppressClipboardPayload = { [weak self] payload in
            self?.clipboardCoordinator.suppressPayload(payload)
        }
        captureCoordinator.historyItems = { [weak self] in
            self?.clipboardCoordinator.historyItems ?? []
        }
        captureCoordinator.setHistoryItems = { [weak self] items in
            self?.clipboardCoordinator.setHistoryItems(items)
        }
        captureCoordinator.promoteItemToFront = { [weak self] id in
            self?.clipboardCoordinator.promoteItemToFront(itemID: id)
        }
        captureCoordinator.currentSettings = { [weak self] in
            self?.settings ?? .default
        }
        captureCoordinator.closeEditor = { [weak self] in
            self?.closeEditorImmediately()
        }
        captureCoordinator.presentError = { [weak self] error, title in
            self?.present(error: error, title: title)
        }

        // Forward both coordinators' objectWillChange into AppState's objectWillChange
        // so views that observe AppState get re-rendered when coordinator state changes.
        coordinatorCancellable = coordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
        captureCoordinatorCancellable = captureCoordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }

        guard enableRuntimeServices else { return }

        historyStore.loadAsync { [weak self] loadedItems, loadedCollections in
            Task { @MainActor in
                self?.clipboardCoordinator.setHistoryItems(loadedItems)
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

        // Clipboard monitor is started via the coordinator.
        coordinator.startMonitor()

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
        // Coordinator handles clipboardMonitor.stop() in its own cleanup.
        let activeAppObserver = activeAppObserver
        let shortcutActionRequestObserver = shortcutActionRequestObserver
        Task { @MainActor in
            if let shortcutActionRequestObserver {
                NotificationCenter.default.removeObserver(shortcutActionRequestObserver)
            }
            if let activeAppObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(activeAppObserver)
            }
        }
    }

    // MARK: - Shortcut / action handling

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
        captureCoordinator.refreshPermissionStatuses()
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
        clipboardCoordinator.trimHistoryToSettingsLimit()
    }

    func restoreDefaultSettings() {
        save(settings: .default)
    }

    // MARK: - Collections

    func createCollection(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !collections.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }

        let collection = ItemCollection(name: trimmed)
        collections.insert(collection, at: 0)
        selectedCollectionID = collection.id
        clipboardCoordinator.persistHistory()
    }

    func deleteCollection(id: UUID) {
        collections.removeAll { $0.id == id }
        if selectedCollectionID == id {
            selectedCollectionID = nil
        }
        clipboardCoordinator.persistHistory()
    }

    func addItem(_ itemID: UUID, toCollection collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        guard !collections[index].itemIDs.contains(itemID) else { return }

        collections[index].itemIDs.insert(itemID, at: 0)
        clipboardCoordinator.persistHistory()
    }

    func removeItem(_ itemID: UUID, fromCollection collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }

        collections[index].itemIDs.removeAll { $0 == itemID }
        clipboardCoordinator.persistHistory()
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

    // MARK: - Clipboard / history delegation

    func toggleFavorite(itemID: UUID) {
        clipboardCoordinator.toggleFavorite(itemID: itemID)
    }

    func deleteItem(itemID: UUID) {
        clipboardCoordinator.deleteItem(itemID: itemID)
    }

    func undoDelete() {
        clipboardCoordinator.undoDelete()
    }

    func copyToClipboard(itemID: UUID) {
        guard let item = clipboardCoordinator.historyItems.first(where: { $0.id == itemID }) else { return }
        _ = clipboardCoordinator.writeItemToClipboard(item)
    }

    func pasteItem(itemID: UUID) {
        guard let item = clipboardCoordinator.historyItems.first(where: { $0.id == itemID }) else { return }
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

    func clearHistory() {
        clipboardCoordinator.clearHistory()
        collections.removeAll()
        selectedCollectionID = nil
    }

    func exportItem(itemID: UUID) {
        guard let item = clipboardCoordinator.historyItems.first(where: { $0.id == itemID }) else { return }
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
        guard let item = clipboardCoordinator.historyItems.first(where: { $0.id == itemID }) else { return }
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

    // MARK: - Editor

    func requestEditorClose() {
        guard let activeScreenshotSession else {
            closeEditorImmediately()
            return
        }
        if activeScreenshotSession.hasUnsavedChanges {
            showEditorDiscardAlert = true
            return
        }
        captureCoordinator.lastScreenshotSession = activeScreenshotSession.duplicateForEditing()
        closeEditorImmediately()
    }

    func discardAndCloseEditor() {
        if let activeScreenshotSession {
            captureCoordinator.lastScreenshotSession = activeScreenshotSession.duplicateForEditing()
        }
        showEditorDiscardAlert = false
        closeEditorImmediately()
    }

    func closeEditorImmediately() {
        showEditorDiscardAlert = false
        windowRouter?.dismissEditor()
        captureCoordinator.activeScreenshotSession = nil
    }

    func editLastScreenshot() {
        guard let lastScreenshotSession else {
            captureCoordinator.captureError = "There is no previous screenshot to edit yet."
            return
        }
        captureCoordinator.openEditor(for: lastScreenshotSession.duplicateForEditing())
    }

    func keepActiveScreenshot() {
        guard let activeScreenshotSession else { return }
        captureCoordinator.commitScreenshotSession(activeScreenshotSession, copyToClipboard: false)
    }

    func copyActiveScreenshot() {
        guard let activeScreenshotSession else { return }
        captureCoordinator.commitScreenshotSession(activeScreenshotSession, copyToClipboard: true)
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
            captureCoordinator.commitScreenshotSession(activeScreenshotSession, copyToClipboard: false)
        } catch {
            present(error: error, title: "Save Failed")
        }
    }

    // MARK: - Diagnostics

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
        History Count: \(clipboardCoordinator.historyItems.count)
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

    // MARK: - Private helpers

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

    private func makePasteBackCoordinator() -> PasteBackCoordinator {
        PasteBackCoordinator(
            writeItemToClipboard: { [weak self] item in
                self?.clipboardCoordinator.writeItemToClipboard(item) ?? false
            },
            closeHub: { [weak self] in
                self?.windowRouter?.dismissHubForPasteBack()
            }
        )
    }

    // MARK: - Capture (delegated to CaptureCoordinator)

    private func startCapture(_ request: CaptureRequest) async {
        await captureCoordinator.startCapture(request)
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
