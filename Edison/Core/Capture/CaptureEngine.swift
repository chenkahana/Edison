import AppKit
import Foundation
import OSLog

final class CaptureEngine {
    static let imageDataUserInfoKey = "imageData"

    @MainActor
    private var regionSelectionSession: RegionSelectionSession?

    func captureArea() {
        Task { @MainActor [weak self] in
            self?.beginRegionSelectionCapture()
        }
    }

    func captureWindow() {
        runScreencapture(arguments: ["-i", "-w", "-x"])
    }

    func captureFullScreen() {
        runScreencapture(arguments: ["-x"])
    }

    @MainActor
    private func beginRegionSelectionCapture() {
        guard regionSelectionSession == nil else { return }

        let session = RegionSelectionSession()
        regionSelectionSession = session

        session.begin { [weak self] selectedRect in
            guard let self else { return }
            self.regionSelectionSession = nil
            guard let selectedRect else { return }
            self.captureSelectedRegion(selectedRect)
        }
    }

    private func captureSelectedRegion(_ selectedRect: CGRect) {
        let standardized = selectedRect.standardized.integral
        guard standardized.width > 1, standardized.height > 1 else { return }
        let rectArgument = [
            Int(standardized.origin.x.rounded(.down)),
            Int(standardized.origin.y.rounded(.down)),
            Int(standardized.width.rounded(.up)),
            Int(standardized.height.rounded(.up))
        ]
        .map(String.init)
        .joined(separator: ",")

        runScreencapture(arguments: ["-R", rectArgument, "-x"])
    }

    private func runScreencapture(arguments: [String]) {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("edison-screenshot-\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments + [outputURL.path]
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                defer {
                    try? FileManager.default.removeItem(at: outputURL)
                }

                guard
                    process.terminationStatus == 0,
                    let imageData = try? Data(contentsOf: outputURL)
                else {
                    let status = process.terminationStatus
                    Log.capture.error("screencapture exited with status \(status)")
                    NotificationCenter.default.post(
                        name: .edisonCaptureFailed,
                        object: nil,
                        userInfo: ["reason": "screencapture exited with status \(status)"]
                    )
                    return
                }

                self?.postCaptureNotification(imageData: imageData)
            }
        }

        do {
            try process.run()
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            Log.capture.error("screencapture launch failed: \(error)")
            NotificationCenter.default.post(name: .edisonCaptureFailed, object: nil)
        }
    }

    private func postCaptureNotification(imageData: Data?) {
        NotificationCenter.default.post(
            name: .edisonScreenshotCaptured,
            object: nil,
            userInfo: [Self.imageDataUserInfoKey: imageData as Any]
        )
    }
}

@MainActor
private final class RegionSelectionSession: NSObject {
    private var windows: [NSWindow] = []
    private var overlays: [SelectionOverlayView] = []
    private var eventMonitors: [Any] = []

    private var dragStartGlobalPoint: CGPoint?
    private var currentGlobalPoint: CGPoint?
    private var completion: ((CGRect?) -> Void)?

    func begin(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion

        NSApp.activate(ignoringOtherApps: true)
        createOverlayWindows()
        startEventTracking()
    }

    private func createOverlayWindows() {
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let overlay = SelectionOverlayView(frame: window.contentView?.bounds ?? .zero)
            overlay.autoresizingMask = [.width, .height]
            window.contentView = overlay
            window.makeKeyAndOrderFront(nil)

            windows.append(window)
            overlays.append(overlay)
        }
    }

    private func startEventTracking() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown]
        let monitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }

        if let monitor {
            eventMonitors.append(monitor)
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .leftMouseDown:
            let location = NSEvent.mouseLocation
            dragStartGlobalPoint = location
            currentGlobalPoint = location
            updateSelectionRect()
            return nil

        case .leftMouseDragged:
            currentGlobalPoint = NSEvent.mouseLocation
            updateSelectionRect()
            return nil

        case .leftMouseUp:
            currentGlobalPoint = NSEvent.mouseLocation
            let rect = makeSelectionRect()
            finish(with: rect)
            return nil

        case .keyDown:
            if event.keyCode == 53 { // Escape
                finish(with: nil)
                return nil
            }
            return event

        default:
            return event
        }
    }

    private func makeSelectionRect() -> CGRect? {
        guard let dragStartGlobalPoint, let currentGlobalPoint else { return nil }
        let rect = CGRect(
            x: min(dragStartGlobalPoint.x, currentGlobalPoint.x),
            y: min(dragStartGlobalPoint.y, currentGlobalPoint.y),
            width: abs(currentGlobalPoint.x - dragStartGlobalPoint.x),
            height: abs(currentGlobalPoint.y - dragStartGlobalPoint.y)
        )
        return rect.width > 1 && rect.height > 1 ? rect : nil
    }

    private func updateSelectionRect() {
        let rect = makeSelectionRect()
        overlays.forEach { $0.selectionRect = rect }
    }

    private func finish(with selectedRect: CGRect?) {
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
        eventMonitors.removeAll()

        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        overlays.removeAll()

        completion?(selectedRect)
        completion = nil
    }
}

private final class SelectionOverlayView: NSView {
    var selectionRect: CGRect? {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        guard let selectionRect else { return }
        let localRect = convertGlobalRectToLocal(selectionRect)

        NSColor.clear.setFill()
        localRect.fill(using: .copy)

        NSColor.white.withAlphaComponent(0.9).setStroke()
        let border = NSBezierPath(rect: localRect)
        border.lineWidth = 2
        border.stroke()
    }

    private func convertGlobalRectToLocal(_ rect: CGRect) -> CGRect {
        guard let frame = window?.frame else { return .zero }
        return CGRect(
            x: rect.origin.x - frame.origin.x,
            y: rect.origin.y - frame.origin.y,
            width: rect.width,
            height: rect.height
        )
    }
}
