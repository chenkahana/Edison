import AppKit
import Combine
import Foundation
import OSLog

enum ClipboardWriteMode: Equatable {
    case sourceFormatting
    case plainText
}

// MARK: - ClipboardCoordinator
//
// Owns history mutation, clipboard writes, and suppression tracking.
// Created and owned by AppState. AppState preserves its public API by
// delegating to this coordinator.
//
// suppressedClipboardPayloads is reserved for screenshot writes that bypass
// writeItemToClipboard and cannot mark the monitor change directly.

@MainActor
final class ClipboardCoordinator: ObservableObject {

    // MARK: - Published state

    @Published private(set) var historyItems: [ClipboardItem] = []
    @Published private(set) var deletedItemForUndo: ClipboardItem?
    @Published private(set) var showDeleteUndoToast = false

    // MARK: - Internal cross-cutting invariant

    /// Payloads manually suppressed by screenshot capture; consumed by addToHistory.
    private(set) var suppressedClipboardPayloads = Set<ClipboardPayload>()

    // MARK: - Dependencies

    private let historyStore: HistoryStore
    private let clipboardMonitor: ClipboardMonitor
    private let representationStore: ClipboardRepresentationStore

    // Collections are owned by AppState (they are a view-model concern that
    // combines history + user organisation). The coordinator receives a closure
    // so it can clean up orphaned itemIDs when history changes.
    var onHistoryChanged: ((_ liveItemIDs: Set<UUID>) -> Void)?

    // Provides the current history limit from AppSettings.
    var historyLimit: () -> Int = { 500 }

    // MARK: - Private state

    private var undoTimer: Timer?

    // MARK: - Init

    init(
        historyStore: HistoryStore,
        clipboardMonitor: ClipboardMonitor,
        representationStore: ClipboardRepresentationStore? = nil
    ) {
        self.historyStore = historyStore
        self.clipboardMonitor = clipboardMonitor
        self.representationStore = representationStore ?? .shared
    }

    // MARK: - Clipboard monitor lifecycle

    // W5.2 retain-cycle audit: the onChange closure captures [weak self], so
    // ClipboardMonitor does not hold a strong reference back to this coordinator.
    // No cycle possible.
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
            deleteAssets(for: item)
            return
        }

        let replacedItems = historyItems.filter { $0.hasSameClipboardIdentity(as: item) }
        historyItems.removeAll { $0.hasSameClipboardIdentity(as: item) }
        replacedItems.filter { $0.id != item.id }.forEach(deleteAssets)
        historyItems.insert(item, at: 0)

        let limit = historyLimit()
        if historyItems.count > limit {
            let excess = historyItems.suffix(historyItems.count - limit)
            excess.forEach(deleteAssets)
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
        excess.forEach(deleteAssets)
        historyItems.removeLast(historyItems.count - limit)
        persistHistory()
    }

    // MARK: - Clipboard write

    @discardableResult
    func writeItemToClipboard(
        _ item: ClipboardItem,
        mode: ClipboardWriteMode = .sourceFormatting
    ) -> Bool {
        let pasteboard = NSPasteboard.general
        defer { clipboardMonitor.markCurrentChangeObserved() }
        pasteboard.clearContents()
        let wroteToPasteboard: Bool

        switch item.payload {
        case let .text(value):
            switch mode {
            case .sourceFormatting:
                wroteToPasteboard = writeSourceFormattedText(item, value: value, to: pasteboard)
            case .plainText:
                wroteToPasteboard = pasteboard.setString(value, forType: .string)
            }
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

    private func writeSourceFormattedText(
        _ item: ClipboardItem,
        value: String,
        to pasteboard: NSPasteboard
    ) -> Bool {
        guard let textRepresentations = item.textRepresentations else {
            return pasteboard.setString(value, forType: .string)
        }

        let richTypeIdentifiers = Set([
            NSPasteboard.PasteboardType.rtf.rawValue,
            NSPasteboard.PasteboardType.rtfd.rawValue,
            NSPasteboard.PasteboardType.html.rawValue
        ])
        let descriptorsByType = Dictionary(
            textRepresentations.storedRepresentations.map { ($0.typeIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let pasteboardItem = NSPasteboardItem()
        var wroteString = false

        for typeIdentifier in textRepresentations.declaredTypeIdentifiers {
            if typeIdentifier == NSPasteboard.PasteboardType.string.rawValue {
                if let descriptor = descriptorsByType[typeIdentifier],
                   let data = try? representationStore.load(descriptor),
                   data == Data(value.utf8) {
                    wroteString = pasteboardItem.setData(data, forType: .string)
                }
                continue
            }

            guard richTypeIdentifiers.contains(typeIdentifier),
                  let descriptor = descriptorsByType[typeIdentifier] else { continue }
            do {
                let data = try representationStore.load(descriptor)
                if !pasteboardItem.setData(data, forType: NSPasteboard.PasteboardType(typeIdentifier)) {
                    Log.store.error(
                        "ClipboardCoordinator: pasteboard rejected representation \(typeIdentifier, privacy: .public)"
                    )
                }
            } catch {
                Log.store.error(
                    "ClipboardCoordinator: skipped unavailable representation \(typeIdentifier, privacy: .public)"
                )
            }
        }

        if !wroteString {
            wroteString = pasteboardItem.setString(value, forType: .string)
        }
        guard wroteString else { return false }
        return pasteboard.writeObjects([pasteboardItem])
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

        if let previousDeletedItem = deletedItemForUndo {
            deleteAssets(for: previousDeletedItem)
        }
        historyItems.remove(at: index)
        onItemDeleted?(itemID)
        persistHistory()

        deletedItemForUndo = item
        showDeleteUndoToast = true
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.deleteAssets(for: item)
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
        undoTimer?.invalidate()
        undoTimer = nil
        if let deletedItemForUndo {
            deleteAssets(for: deletedItemForUndo)
        }
        historyItems.forEach(deleteAssets)
        historyItems.removeAll()
        deletedItemForUndo = nil
        showDeleteUndoToast = false
        persistHistory()
    }

    // MARK: - Direct history write (used by AppState for loaded/screenshot items)

    func setHistoryItems(_ items: [ClipboardItem]) {
        historyItems = items
    }

    func reconcileRepresentationStore() {
        representationStore.reconcile(items: historyItems)
    }

    private func deleteAssets(for item: ClipboardItem) {
        if case let .image(imageData) = item.payload {
            ImageStore.delete(relativePath: imageData.imagePath)
            ImageStore.delete(relativePath: imageData.thumbnailPath)
        }
        representationStore.delete(item.textRepresentations)
    }
}

// MARK: - HistorySource

extension ClipboardCoordinator {
    enum HistorySource {
        case clipboard
        case internalAction
    }
}
