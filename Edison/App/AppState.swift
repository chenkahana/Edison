import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var onboardingCompleted = false
    @Published var activeQuery = ""
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

    weak var windowRouter: WindowRouter?
    private var screenshotObserver: NSObjectProtocol?

    var filteredItems: [ClipboardItem] {
        searchEngine.filter(query: activeQuery, in: historyItems)
    }

    var favoriteItems: [ClipboardItem] {
        filteredItems.filter(\.isFavorite)
    }

    init() {
        Task.detached(priority: .utility) { [historyStore] in
            let loaded = historyStore.load()
            await MainActor.run {
                self.historyItems = loaded
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
            self?.handleScreenshotCapture(note)
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

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.payload {
        case let .text(value):
            pasteboard.setString(value, forType: .string)
        case let .image(data):
            pasteboard.setData(data, forType: .tiff)
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
        persistHistory()
    }

    private func persistHistory() {
        historyStore.save(historyItems)
    }

    private func handleScreenshotCapture(_ note: Notification) {
        let capturedData = (note.userInfo?[CaptureEngine.imageDataUserInfoKey] as? Data)
            ?? NSPasteboard.general.data(forType: .tiff)
        guard let capturedData else { return }

        addToHistory(ClipboardItem(payload: .image(capturedData)))
        editorImageData = capturedData
        windowRouter?.openHub()
        isEditorPresented = true
    }
}

extension Notification.Name {
    static let edisonScreenshotCaptured = Notification.Name("edison.screenshot.captured")
}
