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
    @Published var isEditorPresented = false
    @Published var editorImageData: Data?
    @Published private(set) var deletedItemForUndo: ClipboardItem?
    @Published private(set) var showDeleteUndoToast = false
    @Published var captureError: String?
    @Published private(set) var accessibilityDenied = false
    @Published private(set) var failedShortcutActions: [ShortcutAction] = []

    let shortcutStore = ShortcutStore()
    let hotKeyCenter = HotKeyCenter.shared
    let captureEngine = CaptureEngine()

    private let historyStore = HistoryStore()
    private let clipboardMonitor = ClipboardMonitor()
    private let searchEngine = HistorySearchEngine()
    private let missingWindowError = NSError(
        domain: "Edison.Share",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "No active window available for sharing."]
    )

    private let historyLimit = 250
    private var suppressedClipboardPayloads = Set<ClipboardPayload>()
    private var undoTimer: Timer?

    weak var windowRouter: WindowRouter?
    private var screenshotObserver: NSObjectProtocol?
    private(set) var lastActiveApp: NSRunningApplication?
    private var activeAppObserver: NSObjectProtocol?
    private var shortcutActionRequestObserver: NSObjectProtocol?
    private var captureFailureObserver: NSObjectProtocol?

    var filteredItems: [ClipboardItem] {
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

    var favoriteItems: [ClipboardItem] {
        filteredItems.filter(\.isFavorite)
    }

    init() {
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

        screenshotObserver = NotificationCenter.default.addObserver(
            forName: .edisonScreenshotCaptured,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let capturedData = (note.userInfo?[CaptureEngine.imageDataUserInfoKey] as? Data)
                ?? NSPasteboard.general.data(forType: .tiff)

            MainActor.assumeIsolated {
                self.handleScreenshotCapture(capturedData)
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

        captureFailureObserver = NotificationCenter.default.addObserver(
            forName: .edisonCaptureFailed,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let reason = note.userInfo?["reason"] as? String ?? "Capture failed"
            MainActor.assumeIsolated {
                self?.captureError = reason
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
        let screenshotObserver = screenshotObserver
        let activeAppObserver = activeAppObserver
        let shortcutActionRequestObserver = shortcutActionRequestObserver
        let captureFailureObserver = captureFailureObserver
        Task { @MainActor in
            clipboardMonitor.stop()
            if let screenshotObserver {
                NotificationCenter.default.removeObserver(screenshotObserver)
            }
            if let shortcutActionRequestObserver {
                NotificationCenter.default.removeObserver(shortcutActionRequestObserver)
            }
            if let captureFailureObserver {
                NotificationCenter.default.removeObserver(captureFailureObserver)
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
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        // The dialog is asynchronous — re-check on next paste attempt via AXIsProcessTrusted().
    }

    private func perform(action: ShortcutAction) {
        switch action {
        case .openHub:
            windowRouter?.toggleHub()
        case .captureArea:
            captureEngine.captureArea()
        case .captureWindow:
            captureEngine.captureWindow()
        case .captureFullScreen:
            captureEngine.captureFullScreen()
        }
    }

    func save(shortcuts: ShortcutSet) {
        shortcutStore.save(shortcuts)
        hotKeyCenter.apply(shortcuts: shortcuts)
        failedShortcutActions = hotKeyCenter.failedRegistrations
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
        suppressedClipboardPayloads.insert(item.payload)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        var wroteToPasteboard = false

        switch item.payload {
        case let .text(value):
            pasteboard.setString(value, forType: .string)
            wroteToPasteboard = true
        case let .image(image):
            if let data = try? ImageStore.load(relativePath: image.imagePath) {
                pasteboard.setData(data, forType: .png)
                wroteToPasteboard = true
            }
        case let .fileURL(url):
            pasteboard.writeObjects([url as NSURL])
            wroteToPasteboard = true
        }

        if wroteToPasteboard {
            promoteItemToFront(itemID: itemID)
        }
    }

    func pasteItem(itemID: UUID) {
        copyToClipboard(itemID: itemID)
        windowRouter?.dismissHub()

        let trusted = AXIsProcessTrusted()
        if !trusted {
            Log.permissions.info("Accessibility not granted; paste-back unavailable")
            accessibilityDenied = true
        }
        guard trusted,
              let targetApp = lastActiveApp else {
            // Fallback: item is already in clipboard, user pastes manually
            return
        }

        let pid = targetApp.processIdentifier
        targetApp.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard let source = CGEventSource(stateID: .hidSystemState) else { return }
            let vKeyCode: CGKeyCode = 9 // kVK_ANSI_V
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.postToPid(pid)
            keyUp?.postToPid(pid)
        }
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

    func closeEditor() {
        isEditorPresented = false
    }

    private func addToHistory(_ item: ClipboardItem, source: HistorySource = .clipboard) {
        if source == .clipboard, suppressedClipboardPayloads.remove(item.payload) != nil {
            return
        }

        historyItems.removeAll { $0.payload == item.payload }
        historyItems.insert(item, at: 0)

        if historyItems.count > historyLimit {
            let excess = historyItems.suffix(historyItems.count - historyLimit)
            for pruned in excess {
                if case let .image(imageData) = pruned.payload {
                    ImageStore.delete(relativePath: imageData.imagePath)
                    ImageStore.delete(relativePath: imageData.thumbnailPath)
                }
            }
            historyItems.removeLast(historyItems.count - historyLimit)
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

    private func handleScreenshotCapture(_ capturedData: Data?) {
        guard let capturedData else { return }

        Task { [weak self] in
            let prepared = await Task.detached(priority: .utility) {
                ImageProcessing.prepareImagePayload(from: capturedData)
            }.value

            guard let prepared else { return }
            await MainActor.run {
                guard let self else { return }
                self.suppressedClipboardPayloads.insert(.image(prepared))
                self.addToHistory(ClipboardItem(payload: .image(prepared)), source: .internalAction)
                self.editorImageData = try? ImageStore.load(relativePath: prepared.imagePath)
                self.windowRouter?.openHub()
                self.isEditorPresented = true
            }
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
