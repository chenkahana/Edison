import AppKit
import CoreGraphics
import Foundation
import OSLog
import ScreenCaptureKit

enum CaptureRequest {
    case screenshot
    case window
    case fullScreen
    case previousArea
}

enum CaptureResult {
    case success(data: Data, displayID: CGDirectDisplayID?, rect: CGRect?)
    case cancelled
    case permissionDenied
    case failure(String)
}

@MainActor
final class CaptureEngine {
    private var selectionSession: RegionSelectionSession?
    private var lastAreaByDisplay: [CGDirectDisplayID: CGRect] = [:]

    var hasPreviousArea: Bool {
        !lastAreaByDisplay.isEmpty
    }

    func capture(_ request: CaptureRequest, settings: AppSettings) async -> CaptureResult {
        guard CGPreflightScreenCaptureAccess() else {
            Log.permissions.info("Capture blocked because Screen Recording is not granted")
            return .permissionDenied
        }

        switch request {
        case .screenshot:
            return await interactiveCapture(initialMode: .area, settings: settings)
        case .window:
            return await interactiveCapture(initialMode: .window, settings: settings)
        case .fullScreen:
            guard let displayID = displayIDForCurrentPointer() ?? primaryDisplayID() else {
                return .failure("No display available for capture.")
            }
            return await captureDisplay(displayID: displayID)
        case .previousArea:
            guard settings.capture.rememberLastArea,
                  let displayID = displayIDForCurrentPointer() ?? lastAreaByDisplay.keys.first,
                  let rect = lastAreaByDisplay[displayID] else {
                return .failure("No previous capture area is available yet.")
            }
            return await captureArea(rect, displayID: displayID)
        }
    }

    func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    private func interactiveCapture(initialMode: SelectionMode, settings: AppSettings) async -> CaptureResult {
        let selection = await withCheckedContinuation { continuation in
            let session = RegionSelectionSession(showMeasurements: settings.capture.showMagnifierAndDimensions)
            selectionSession = session
            session.begin(initialMode: initialMode) { [weak self] result in
                self?.selectionSession = nil
                continuation.resume(returning: result)
            }
        }

        switch selection {
        case let .area(rect, displayID):
            if settings.capture.rememberLastArea, let displayID {
                lastAreaByDisplay[displayID] = rect
            }
            return await captureArea(rect, displayID: displayID)
        case let .window(windowID):
            return await captureWindow(windowID: windowID)
        case let .display(displayID):
            return await captureDisplay(displayID: displayID)
        case .cancelled:
            return .cancelled
        }
    }

    private func captureArea(_ rect: CGRect, displayID: CGDirectDisplayID?) async -> CaptureResult {
        let standardized = rect.standardized.integral
        guard standardized.width > 1, standardized.height > 1 else {
            return .cancelled
        }

        if #available(macOS 15.2, *) {
            do {
                let image = try await Self.captureImage(in: standardized)
                return .success(data: image, displayID: displayID, rect: standardized)
            } catch {
                Log.capture.error("ScreenCaptureKit area capture failed – \(error.localizedDescription)")
            }
        }

        if let displayID,
           let data = try? await captureAreaOnDisplay(standardized, displayID: displayID) {
            return .success(data: data, displayID: displayID, rect: standardized)
        }

        if let data = try? await LegacyScreenshotCapture.capture(arguments: [
            "-R",
            [
                Int(standardized.origin.x.rounded(.down)),
                Int(standardized.origin.y.rounded(.down)),
                Int(standardized.width.rounded(.up)),
                Int(standardized.height.rounded(.up))
            ].map(String.init).joined(separator: ","),
            "-x"
        ]) {
            return .success(data: data, displayID: displayID, rect: standardized)
        }

        return .failure("Unable to capture the selected area.")
    }

    private func captureWindow(windowID: CGWindowID) async -> CaptureResult {
        do {
            let content = try await SCShareableContent.current
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                return .failure("The selected window is no longer available.")
            }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = SCStreamConfiguration()
            configuration.width = max(1, Int(window.frame.width * pointPixelScale(for: window.frame).rounded()))
            configuration.height = max(1, Int(window.frame.height * pointPixelScale(for: window.frame).rounded()))
            configuration.scalesToFit = false
            configuration.showsCursor = false

            let image = try await Self.captureImage(filter: filter, configuration: configuration)
            return .success(data: image, displayID: displayID(containing: window.frame.mid), rect: window.frame)
        } catch {
            Log.capture.error("Window capture failed – \(error.localizedDescription)")
            return .failure("Unable to capture the selected window.")
        }
    }

    private func captureDisplay(displayID: CGDirectDisplayID) async -> CaptureResult {
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                return .failure("The selected display is no longer available.")
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            if #available(macOS 14.2, *) {
                filter.includeMenuBar = true
            }

            let configuration = SCStreamConfiguration()
            configuration.width = max(1, Int(CGDisplayPixelsWide(displayID)))
            configuration.height = max(1, Int(CGDisplayPixelsHigh(displayID)))
            configuration.scalesToFit = false
            configuration.showsCursor = false

            let image = try await Self.captureImage(filter: filter, configuration: configuration)
            return .success(data: image, displayID: displayID, rect: display.frame)
        } catch {
            Log.capture.error("Display capture failed – \(error.localizedDescription)")
            return .failure("Unable to capture the current display.")
        }
    }

    private func captureAreaOnDisplay(_ rect: CGRect, displayID: CGDirectDisplayID) async throws -> Data {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        if #available(macOS 14.2, *) {
            filter.includeMenuBar = true
        }

        let displayFrame = display.frame
        let sourceRect = CGRect(
            x: rect.minX - displayFrame.minX,
            y: rect.minY - displayFrame.minY,
            width: rect.width,
            height: rect.height
        )

        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(rect.width * pointPixelScale(for: rect).rounded()))
        configuration.height = max(1, Int(rect.height * pointPixelScale(for: rect).rounded()))
        configuration.sourceRect = sourceRect
        configuration.scalesToFit = false
        configuration.showsCursor = false

        return try await Self.captureImage(filter: filter, configuration: configuration)
    }

    private func pointPixelScale(for rect: CGRect) -> CGFloat {
        guard let displayID = displayID(containing: rect.mid) else { return 2 }
        let pixelsWide = CGFloat(CGDisplayPixelsWide(displayID))
        let boundsWide = max(CGDisplayBounds(displayID).width, 1)
        return max(1, pixelsWide / boundsWide)
    }

    private func displayID(containing point: CGPoint) -> CGDirectDisplayID? {
        displayIDForCurrentPointer(point: point)
    }

    private func displayIDForCurrentPointer(point: CGPoint = NSEvent.mouseLocation) -> CGDirectDisplayID? {
        for screen in NSScreen.screens where screen.frame.contains(point) {
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                return CGDirectDisplayID(number.uint32Value)
            }
        }
        return nil
    }

    private func primaryDisplayID() -> CGDirectDisplayID? {
        guard let screen = NSScreen.main,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private static func captureImage(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image else {
                    continuation.resume(throwing: CocoaError(.fileReadUnknown))
                    return
                }
                guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    continuation.resume(throwing: CocoaError(.fileWriteUnknown))
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    @available(macOS 15.2, *)
    private static func captureImage(in rect: CGRect) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: rect) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image else {
                    continuation.resume(throwing: CocoaError(.fileReadUnknown))
                    return
                }
                guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    continuation.resume(throwing: CocoaError(.fileWriteUnknown))
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }
}

private enum SelectionMode {
    case area
    case window
}

private enum SelectionResult {
    case area(CGRect, CGDirectDisplayID?)
    case window(CGWindowID)
    case display(CGDirectDisplayID)
    case cancelled
}

@MainActor
private final class RegionSelectionSession: NSObject {
    private var windows: [NSWindow] = []
    private var overlays: [SelectionOverlayView] = []
    private var eventMonitors: [Any] = []
    private let showMeasurements: Bool

    private var dragStartPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var mode: SelectionMode = .area
    private var completion: ((SelectionResult) -> Void)?

    init(showMeasurements: Bool) {
        self.showMeasurements = showMeasurements
    }

    func begin(initialMode: SelectionMode, completion: @escaping (SelectionResult) -> Void) {
        self.mode = initialMode
        self.completion = completion

        NSApp.activate(ignoringOtherApps: true)
        createOverlayWindows()
        startEventTracking()
        updateHoverState()
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
            overlay.snapshot = displaySnapshot(for: screen)
            overlay.showMeasurements = showMeasurements
            overlay.mode = mode
            window.contentView = overlay
            window.makeKeyAndOrderFront(nil)

            windows.append(window)
            overlays.append(overlay)
        }
    }

    private func startEventTracking() {
        let localMask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown, .mouseMoved]
        if let local = NSEvent.addLocalMonitorForEvents(matching: localMask, handler: { [weak self] event in
            guard let self else { return event }
            return handle(event)
        }) {
            eventMonitors.append(local)
        }

        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateHoverState()
            }
        }) {
            eventMonitors.append(global)
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .leftMouseDown:
            if mode == .window {
                finish(with: currentWindowSelection() ?? .cancelled)
                return nil
            }
            let location = NSEvent.mouseLocation
            dragStartPoint = location
            currentPoint = location
            updateSelectionRect()
            return nil

        case .leftMouseDragged:
            guard mode == .area else { return nil }
            currentPoint = NSEvent.mouseLocation
            updateSelectionRect()
            return nil

        case .leftMouseUp:
            guard mode == .area else { return nil }
            currentPoint = NSEvent.mouseLocation
            let rect = makeSelectionRect()
            finish(with: .area(rect ?? .zero, displayID(containing: rect?.mid)))
            return nil

        case .mouseMoved:
            updateHoverState()
            return nil

        case .keyDown:
            switch event.keyCode {
            case 53:
                finish(with: .cancelled)
            case 49:
                mode = mode == .area ? .window : .area
                dragStartPoint = nil
                currentPoint = nil
                updateSelectionRect()
                updateHoverState()
            case 3:
                if let displayID = displayID(containing: NSEvent.mouseLocation) {
                    finish(with: .display(displayID))
                }
            default:
                return event
            }
            return nil

        default:
            return event
        }
    }

    private func makeSelectionRect() -> CGRect? {
        guard let dragStartPoint, let currentPoint else { return nil }
        let rect = CGRect(
            x: min(dragStartPoint.x, currentPoint.x),
            y: min(dragStartPoint.y, currentPoint.y),
            width: abs(currentPoint.x - dragStartPoint.x),
            height: abs(currentPoint.y - dragStartPoint.y)
        )
        return rect.width > 1 && rect.height > 1 ? rect : nil
    }

    private func updateSelectionRect() {
        let rect = makeSelectionRect()
        overlays.forEach {
            $0.selectionRect = rect
            $0.mode = mode
        }
    }

    private func updateHoverState() {
        let mouseLocation = NSEvent.mouseLocation
        let windowRect = currentWindowRect(at: mouseLocation)
        let displayRect = displayRect(containing: mouseLocation)
        overlays.forEach {
            $0.pointerLocation = mouseLocation
            $0.highlightedWindowRect = mode == .window ? windowRect : nil
            $0.highlightedDisplayRect = displayRect
            $0.mode = mode
        }
    }

    private func currentWindowSelection() -> SelectionResult? {
        guard let windowInfo = currentWindowInfo(at: NSEvent.mouseLocation) else { return nil }
        return .window(windowInfo.windowID)
    }

    private func currentWindowRect(at point: CGPoint) -> CGRect? {
        currentWindowInfo(at: point)?.frame
    }

    private func currentWindowInfo(at point: CGPoint) -> WindowSelectionInfo? {
        let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for info in infoList {
            guard
                let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                ownerPID != ProcessInfo.processInfo.processIdentifier,
                let windowNumber = info[kCGWindowNumber as String] as? UInt32,
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == 0
            else {
                continue
            }

            let rect = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            guard rect.contains(point), rect.width > 10, rect.height > 10 else { continue }
            return WindowSelectionInfo(windowID: CGWindowID(windowNumber), frame: rect)
        }
        return nil
    }

    private func displayRect(containing point: CGPoint) -> CGRect? {
        NSScreen.screens.first(where: { $0.frame.contains(point) })?.frame
    }

    private func displayID(containing point: CGPoint?) -> CGDirectDisplayID? {
        guard let point else { return nil }
        for screen in NSScreen.screens where screen.frame.contains(point) {
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                return CGDirectDisplayID(number.uint32Value)
            }
        }
        return nil
    }

    private func displaySnapshot(for screen: NSScreen) -> NSImage? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let image = CGDisplayCreateImage(CGDirectDisplayID(number.uint32Value)) else {
            return nil
        }
        return NSImage(cgImage: image, size: screen.frame.size)
    }

    private func finish(with result: SelectionResult) {
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
        eventMonitors.removeAll()

        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        overlays.removeAll()

        completion?(result)
        completion = nil
    }
}

private struct WindowSelectionInfo {
    var windowID: CGWindowID
    var frame: CGRect
}

private final class SelectionOverlayView: NSView {
    var snapshot: NSImage? { didSet { needsDisplay = true } }
    var selectionRect: CGRect? { didSet { needsDisplay = true } }
    var highlightedWindowRect: CGRect? { didSet { needsDisplay = true } }
    var highlightedDisplayRect: CGRect? { didSet { needsDisplay = true } }
    var pointerLocation: CGPoint? { didSet { needsDisplay = true } }
    var showMeasurements = true { didSet { needsDisplay = true } }
    var mode: SelectionMode = .area { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let snapshot {
            snapshot.draw(in: bounds)
        } else {
            NSColor.black.setFill()
            bounds.fill()
        }

        NSColor.black.withAlphaComponent(0.28).setFill()
        dirtyRect.fill()

        if let highlightedDisplayRect {
            let local = convertGlobalRectToLocal(highlightedDisplayRect)
            NSColor.white.withAlphaComponent(0.08).setFill()
            local.fill()
        }

        if mode == .window, let highlightedWindowRect {
            let local = convertGlobalRectToLocal(highlightedWindowRect)
            NSColor.clear.setFill()
            local.fill(using: .copy)
            NSColor.systemOrange.withAlphaComponent(0.95).setStroke()
            let path = NSBezierPath(roundedRect: local, xRadius: 12, yRadius: 12)
            path.lineWidth = 3
            path.stroke()
        }

        if let selectionRect {
            let local = convertGlobalRectToLocal(selectionRect)
            NSColor.clear.setFill()
            local.fill(using: .copy)

            NSColor.white.withAlphaComponent(0.92).setStroke()
            let path = NSBezierPath(rect: local)
            path.lineWidth = 2
            path.stroke()

            if showMeasurements {
                drawMeasurementBadge(for: local, globalRect: selectionRect)
            }
        }

        drawInstructions()
    }

    private func drawInstructions() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85),
            .paragraphStyle: paragraph
        ]

        let title = mode == .area ? "Drag to capture an area" : "Click a window to capture it"
        let subtitle = "Space switches area/window, F captures the current display, Esc cancels"
        NSAttributedString(string: title, attributes: attributes)
            .draw(in: CGRect(x: 24, y: bounds.height - 54, width: bounds.width - 48, height: 20))
        NSAttributedString(string: subtitle, attributes: subtitleAttributes)
            .draw(in: CGRect(x: 24, y: bounds.height - 74, width: bounds.width - 48, height: 18))
    }

    private func drawMeasurementBadge(for localRect: CGRect, globalRect: CGRect) {
        let text = "\(Int(globalRect.width)) × \(Int(globalRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        let badgeRect = CGRect(
            x: localRect.minX,
            y: max(localRect.maxY + 8, 16),
            width: size.width + 16,
            height: size.height + 10
        )
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 10, yRadius: 10).fill()
        string.draw(at: CGPoint(x: badgeRect.minX + 8, y: badgeRect.minY + 5))
    }

    private func convertGlobalRectToLocal(_ rect: CGRect) -> CGRect {
        let localOrigin = convert(rect.origin, from: nil)
        return CGRect(
            x: localOrigin.x,
            y: localOrigin.y,
            width: rect.width,
            height: rect.height
        )
    }
}

private enum LegacyScreenshotCapture {
    static func capture(arguments: [String]) async throws -> Data {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("edison-screenshot-\(UUID().uuidString).png")

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = arguments + [outputURL.path]
            process.terminationHandler = { process in
                defer { try? FileManager.default.removeItem(at: outputURL) }

                guard process.terminationStatus == 0 else {
                    continuation.resume(throwing: CocoaError(.userCancelled))
                    return
                }

                do {
                    let data = try Data(contentsOf: outputURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            do {
                try process.run()
            } catch {
                try? FileManager.default.removeItem(at: outputURL)
                continuation.resume(throwing: error)
            }
        }
    }
}

private extension CGRect {
    var mid: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
