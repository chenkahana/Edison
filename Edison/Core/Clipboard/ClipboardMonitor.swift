import AppKit
import Foundation

final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int
    private var onNewItem: ((ClipboardItem) -> Void)?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(onNewItem: @escaping (ClipboardItem) -> Void) {
        self.onNewItem = onNewItem
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let item = makeClipboardItem() else { return }
        onNewItem?(item)
    }

    private func makeClipboardItem() -> ClipboardItem? {
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return ClipboardItem(payload: .text(text))
        }

        if let tiffData = pasteboard.data(forType: .tiff),
           let optimized = optimizeImageData(tiffData) {
            return ClipboardItem(payload: .image(optimized))
        }

        if let value = pasteboard.string(forType: .fileURL),
           let url = URL(string: value) {
            return ClipboardItem(payload: .fileURL(url))
        }

        return nil
    }

    private func optimizeImageData(_ input: Data) -> Data? {
        guard let image = NSImage(data: input) else { return nil }

        let maxDimension: CGFloat = 2200
        let scaled = image.resized(maxDimension: maxDimension)
        return scaled.pngData() ?? input
    }
}

private extension NSImage {
    func resized(maxDimension: CGFloat) -> NSImage {
        let size = self.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }

        let ratio = maxDimension / longest
        let targetSize = NSSize(width: size.width * ratio, height: size.height * ratio)
        let output = NSImage(size: targetSize)

        output.lockFocus()
        draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1)
        output.unlockFocus()
        return output
    }

    func pngData() -> Data? {
        guard
            let tiffData = tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}
