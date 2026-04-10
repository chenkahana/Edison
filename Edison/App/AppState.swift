import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    private enum HistorySource {
        case clipboard
        case internalAction
    }

    @Published var activeQuery = ""
    @Published var selectedTypeFilter: HistoryItemTypeFilter = .all
    @Published private(set) var historyItems: [ClipboardItem] = []
    @Published var isEditorPresented = false
    @Published var editorImageData: Data?

    let shortcutStore = ShortcutStore()
    let hotKeyCenter = HotKeyCenter.shared
    let captureEngine = CaptureEngine()

    private let historyStore = HistoryStore()
    private let clipboardMonitor = ClipboardMonitor()
    private let searchEngine = HistorySearchEngine()

    private let historyLimit = 250
    private var suppressedClipboardPayloads = Set<ClipboardPayload>()

    weak var windowRouter: WindowRouter?
    private var screenshotObserver: NSObjectProtocol?

    var filteredItems: [ClipboardItem] {
        searchEngine.filter(query: activeQuery, in: historyItems, type: selectedTypeFilter)
    }

    var favoriteItems: [ClipboardItem] {
        filteredItems.filter(\.isFavorite)
    }

    init() {
        historyStore.loadAsync { [weak self] loaded in
            Task { @MainActor in
                self?.historyItems = loaded
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

    func toggleFavorite(itemID: UUID) {
        guard let index = historyItems.firstIndex(where: { $0.id == itemID }) else { return }
        historyItems[index].isFavorite.toggle()
        persistHistory()
    }

    func copyToClipboard(itemID: UUID) {
        guard let item = historyItems.first(where: { $0.id == itemID }) else { return }
        suppressedClipboardPayloads.insert(item.payload)

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

    private func addToHistory(_ item: ClipboardItem, source: HistorySource = .clipboard) {
        if source == .clipboard, suppressedClipboardPayloads.remove(item.payload) != nil {
            return
        }

        historyItems.removeAll { $0.payload == item.payload }
        historyItems.insert(item, at: 0)

        if historyItems.count > historyLimit {
            historyItems.removeLast(historyItems.count - historyLimit)
        }
        persistHistory()
    }

    private func persistHistory() {
        historyStore.save(historyItems)
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
