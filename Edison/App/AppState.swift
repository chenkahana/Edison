import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var activeQuery = ""
    @Published private(set) var historyItems: [ClipboardItem] = []
    @Published private(set) var collections: [ItemCollection] = []
    @Published var selectedCollectionID: UUID?
    @Published var isEditorPresented = false
    @Published var editorImageData: Data?

    let shortcutStore = ShortcutStore()
    let hotKeyCenter = HotKeyCenter.shared
    let captureEngine = CaptureEngine()

    private let historyStore = HistoryStore()
    private let clipboardMonitor = ClipboardMonitor()
    private let searchEngine = HistorySearchEngine()

    private let historyLimit = 250

    weak var windowRouter: WindowRouter?
    private var screenshotObserver: NSObjectProtocol?

    var filteredItems: [ClipboardItem] {
        let searched = searchEngine.filter(query: activeQuery, in: historyItems)
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
    }

    deinit {
        clipboardMonitor.stop()
        if let screenshotObserver {
            NotificationCenter.default.removeObserver(screenshotObserver)
        }
    }

    func handle(hotKeyAction: ShortcutAction) {
        switch hotKeyAction {
        case .openHub:
            windowRouter?.openHub()
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

    func copyToClipboard(itemID: UUID) {
        guard let item = historyItems.first(where: { $0.id == itemID }) else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.payload {
        case let .text(value):
            pasteboard.setString(value, forType: .string)
        case let .image(image):
            pasteboard.setData(image.data, forType: .png)
        case let .fileURL(url):
            pasteboard.writeObjects([url as NSURL])
        }
    }

    func closeEditor() {
        isEditorPresented = false
    }

    private func addToHistory(_ item: ClipboardItem) {
        historyItems.removeAll { $0.payload == item.payload }
        historyItems.insert(item, at: 0)

        if historyItems.count > historyLimit {
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
                self.addToHistory(ClipboardItem(payload: .image(prepared)))
                self.editorImageData = prepared.data
                self.windowRouter?.openHub()
                self.isEditorPresented = true
            }
        }
    }
}

extension Notification.Name {
    static let edisonScreenshotCaptured = Notification.Name("edison.screenshot.captured")
}
