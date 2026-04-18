import AppKit
import Combine
import Foundation
import OSLog

// MARK: - ClipboardCoordinator
//
// Owns history mutation, clipboard writes, and suppression tracking.
// Created and owned by AppState. AppState preserves its public API by
// delegating to this coordinator.
//
// suppressedClipboardPayloads lives here because both addToHistory (reading)
// and writeItemToClipboard / suppressPayload (writing) must agree on the same
// set. AppState.writeImageDataToClipboard calls coordinator.suppressPayload(_:)
// rather than reaching into the set directly, keeping the mutation boundary clear.

@MainActor
final class ClipboardCoordinator: ObservableObject {

    // MARK: - Published state

    @Published private(set) var historyItems: [ClipboardItem] = []
    @Published private(set) var deletedItemForUndo: ClipboardItem?
    @Published private(set) var showDeleteUndoToast = false

    // MARK: - Internal cross-cutting invariant

    /// Payloads written by Edison itself; addToHistory skips them to avoid
    /// re-inserting items that Edison just placed on the clipboard.
    private(set) var suppressedClipboardPayloads = Set<ClipboardPayload>()

    // MARK: - Dependencies

    private let historyStore: HistoryStore
    private let clipboardMonitor: ClipboardMonitor

    // Collections are owned by AppState (they are a view-model concern that
    // combines history + user organisation). The coordinator receives a closure
    // so it can clean up orphaned itemIDs when history changes.
    var onHistoryChanged: ((_ liveItemIDs: Set<UUID>) -> Void)?

    // Provides the current history limit from AppSettings.
    var historyLimit: () -> Int = { 500 }

    // MARK: - Private state

    private var undoTimer: Timer?

    // MARK: - Init

    init(historyStore: HistoryStore, clipboardMonitor: ClipboardMonitor) {
        self.historyStore = historyStore
        self.clipboardMonitor = clipboardMonitor
    }

    // MARK: - Clipboard monitor lifecycle

    func startMonitor() {
        clipboardMonitor.start { [weak self] newItem in
            Task { @MainActor in
                self?.addToHistory(newItem)
            }
        }
    }

    func stopMonitor() {
        clipboardMonitor.stop()
    }

    // MARK: - History mutation

    func addToHistory(_ item: ClipboardItem, source: HistorySource = .clipboard) {
        if source == .clipboard, suppressedClipboardPayloads.remove(item.payload) != nil {
            return
        }

        historyItems.removeAll { $0.payload == item.payload }
        historyItems.insert(item, at: 0)

        let limit = historyLimit()
        if historyItems.count > limit {
            let excess = historyItems.suffix(historyItems.count - limit)
            for pruned in excess {
                if case let .image(imageData) = pruned.payload {
                    ImageStore.delete(relativePath: imageData.imagePath)
                    ImageStore.delete(relativePath: imageData.thumbnailPath)
                }
            }
            historyItems.removeLast(historyItems.count - limit)
        }

        let liveItemIDs = Set(historyItems.map(\.id))
        onHistoryChanged?(liveItemIDs)

        persistHistory()
    }

    func persistHistory() {
        // Collections are passed in by AppState via the save closure.
        onPersistRequested?()
    }

    /// Called by AppState to actually write to disk; set during init by AppState.
    var onPersistRequested: (() -> Void)?

    func trimHistoryToSettingsLimit() {
        let limit = historyLimit()
        guard historyItems.count > limit else { return }
        let excess = historyItems.suffix(historyItems.count - limit)
        for pruned in excess {
            if case let .image(imageData) = pruned.payload {
                ImageStore.delete(relativePath: imageData.imagePath)
                ImageStore.delete(relativePath: imageData.thumbnailPath)
            }
        }
        historyItems.removeLast(historyItems.count - limit)
        persistHistory()
    }

    // MARK: - Clipboard write

    @discardableResult
    func writeItemToClipboard(_ item: ClipboardItem) -> Bool {
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

    /// Suppresses a payload without writing to the pasteboard (used by
    /// writeImageDataToClipboard in AppState for screenshot capture results).
    func suppressPayload(_ payload: ClipboardPayload) {
        suppressedClipboardPayloads.insert(payload)
    }

    // MARK: - Item operations

    func deleteItem(itemID: UUID) {
        guard let index = historyItems.firstIndex(where: { $0.id == itemID }) else { return }
        let item = historyItems[index]

        historyItems.remove(at: index)
        onItemDeleted?(itemID)
        persistHistory()

        deletedItemForUndo = item
        showDeleteUndoToast = true
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Undo window expired — now safe to remove image files from disk.
                if case let .image(imageData) = item.payload {
                    ImageStore.delete(relativePath: imageData.imagePath)
                    ImageStore.delete(relativePath: imageData.thumbnailPath)
                }
                self?.showDeleteUndoToast = false
                self?.deletedItemForUndo = nil
            }
        }
    }

    /// Called by AppState so it can remove the deleted item from collections.
    var onItemDeleted: ((UUID) -> Void)?

    func undoDelete() {
        guard let item = deletedItemForUndo else { return }
        undoTimer?.invalidate()
        undoTimer = nil
        historyItems.insert(item, at: 0)
        persistHistory()
        deletedItemForUndo = nil
        showDeleteUndoToast = false
    }

    func toggleFavorite(itemID: UUID) {
        guard let index = historyItems.firstIndex(where: { $0.id == itemID }) else { return }
        historyItems[index].isFavorite.toggle()
        persistHistory()
    }

    func promoteItemToFront(itemID: UUID) {
        guard let index = historyItems.firstIndex(where: { $0.id == itemID }) else { return }
        var item = historyItems.remove(at: index)
        item.createdAt = .now
        historyItems.insert(item, at: 0)
        persistHistory()
    }

    func clearHistory() {
        historyItems.forEach { item in
            if case let .image(imageData) = item.payload {
                ImageStore.delete(relativePath: imageData.imagePath)
                ImageStore.delete(relativePath: imageData.thumbnailPath)
            }
        }
        historyItems.removeAll()
        persistHistory()
    }

    // MARK: - Direct history write (used by AppState for loaded/screenshot items)

    func setHistoryItems(_ items: [ClipboardItem]) {
        historyItems = items
    }
}

// MARK: - HistorySource

extension ClipboardCoordinator {
    enum HistorySource {
        case clipboard
        case internalAction
    }
}
