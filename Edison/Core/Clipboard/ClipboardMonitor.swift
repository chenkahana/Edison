import AppKit
import Foundation

final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int
    private var onNewItem: ((ClipboardItem) -> Void)?
    private var wakeObserver: NSObjectProtocol?
    private let processingQueue = DispatchQueue(label: "edison.clipboard.processing", qos: .utility)

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(onNewItem: @escaping (ClipboardItem) -> Void) {
        self.onNewItem = onNewItem
        timer?.invalidate()
        registerWakeObserverIfNeeded()

        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        processPasteboardSnapshot()
    }

    private func registerWakeObserverIfNeeded() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWake()
        }
    }

    private func handleWake() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        processPasteboardSnapshot()
    }

    private func processPasteboardSnapshot() {
        let pasteboard = self.pasteboard
        processingQueue.async { [weak self] in
            guard let item = self?.makeClipboardItem(from: pasteboard) else { return }
            DispatchQueue.main.async {
                self?.onNewItem?(item)
            }
        }
    }

    private func makeClipboardItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return ClipboardItem(payload: .text(text))
        }

        if let tiffData = pasteboard.data(forType: .tiff),
           let prepared = ImageProcessing.prepareImagePayload(from: tiffData) {
            return ClipboardItem(payload: .image(prepared))
        }

        if let fileURL = pasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL {
            return ClipboardItem(payload: .fileURL(fileURL))
        }

        if let value = pasteboard.string(forType: .fileURL),
           let url = URL(string: value) {
            return ClipboardItem(payload: .fileURL(url))
        }

        return nil
    }
}
