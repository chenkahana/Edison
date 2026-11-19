import AppKit

/// The floating thumbnail after a capture, as macOS ⇧⌘5 shows it: bottom-right of the display, gone after 5 s
/// (kept while the pointer is on it). Click to annotate, drag into any app, swipe right to put it away.
/// The capture is already in history, so dismissing loses nothing.
@MainActor
final class CaptureThumbnail {
    private static let width: CGFloat = 200
    private static let margin: CGFloat = 20
    private static let lifetime: TimeInterval = 5

    private var panel: NSPanel?
    private var dismissTimer: Timer?

    func show(pngData: Data, fileName: String, on screen: NSScreen?, onOpen: @escaping () -> Void) {
        close()
        guard let image = NSImage(data: pngData), image.size.width > 0, image.size.height > 0,
              let screen = screen ?? NSScreen.main else { return }

        let height = min(Self.width * image.size.height / image.size.width, Self.width * 1.5)
        let frame = NSRect(
            x: screen.visibleFrame.maxX - Self.width - Self.margin,
            y: screen.visibleFrame.minY + Self.margin,
            width: Self.width,
            height: height
        )
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let view = CaptureThumbnailView(frame: NSRect(origin: .zero, size: frame.size))
        view.image = image
        view.pngData = pngData
        view.fileName = fileName
        view.onOpen = { [weak self] in
            self?.close()
            onOpen()
        }
        view.onSwipeAway = { [weak self] in self?.slideOutAndClose() }
        view.onHoverChanged = { [weak self] hovering in
            if hovering { self?.dismissTimer?.invalidate() } else { self?.scheduleDismiss() }
        }
        panel.contentView = view
        panel.orderFrontRegardless()
        self.panel = panel
        scheduleDismiss()
    }

    func close() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func scheduleDismiss() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: Self.lifetime, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.slideOutAndClose() }
        }
    }

    private func slideOutAndClose() {
        guard let panel else { return }
        var target = panel.frame
        target.origin.x = (panel.screen?.frame.maxX ?? target.maxX) + Self.margin
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.2
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { self.close() }
        }
    }
}

private final class CaptureThumbnailView: NSView, NSDraggingSource {
    var image: NSImage?
    var pngData = Data()
    var fileName = "Edison Screenshot"
    var onOpen: () -> Void = {}
    var onSwipeAway: () -> Void = {}
    var onHoverChanged: (Bool) -> Void = { _ in }

    private var mouseDownPoint: NSPoint?
    private var startFrame: NSRect?
    private var isSwiping = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.4).cgColor
        setAccessibilityRole(.button)
        setAccessibilityLabel("Screenshot thumbnail")
        setAccessibilityHelp("Opens the screenshot in the editor")
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { onHoverChanged(true) }
    override func mouseExited(with event: NSEvent) { onHoverChanged(false) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        image?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = NSEvent.mouseLocation
        startFrame = window?.frame
        isSwiping = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint, let startFrame, let window else { return }
        let dx = NSEvent.mouseLocation.x - start.x
        let dy = NSEvent.mouseLocation.y - start.y
        if !isSwiping, hypot(dx, dy) < 4 { return }

        // A rightward drag swipes the thumbnail away; any other drag carries the image out.
        if isSwiping || (dx > 0 && abs(dx) > abs(dy) * 2) {
            isSwiping = true
            window.setFrameOrigin(NSPoint(x: startFrame.minX + max(0, dx), y: startFrame.minY))
            return
        }
        mouseDownPoint = nil
        beginDragOut(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownPoint = nil }
        guard mouseDownPoint != nil else { return }
        if isSwiping, let startFrame, let window {
            if window.frame.minX - startFrame.minX > 50 {
                onSwipeAway()
            } else {
                window.setFrame(startFrame, display: true, animate: true)
            }
            return
        }
        onOpen()
    }

    private func beginDragOut(with event: NSEvent) {
        let item = NSPasteboardItem()
        item.setData(pngData, forType: .png)
        let name = fileName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: ".")
        if let url = try? TemporaryFiles.url(in: .dragOut, subfolder: UUID().uuidString, fileName: name + ".png"),
           (try? pngData.write(to: url, options: .atomic)) != nil {
            item.setString(url.absoluteString, forType: .fileURL)
        }
        let draggingItem = NSDraggingItem(pasteboardWriter: item)
        draggingItem.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}
