import AppKit

@MainActor
final class WindowRouter {
    private weak var hubWindow: NSWindow?
    private var openHubAction: (() -> Void)?
    private var hubRequestedVisible = false

    // MARK: - Shelf height persistence

    private static let shelfHeightKey = "edison.shelfHeight"
    private static let minShelfHeight: CGFloat = 156
    private static let maxShelfHeight: CGFloat = 480

    private var storedShelfHeight: CGFloat {
        get {
            let stored = CGFloat(UserDefaults.standard.double(forKey: Self.shelfHeightKey))
            guard stored >= Self.minShelfHeight else { return 360 }
            return min(stored, Self.maxShelfHeight)
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: Self.shelfHeightKey)
        }
    }

    func toggleHub() {
        if isHubPresented {
            dismissHub()
        } else {
            openHub()
        }
    }

    func registerHubWindow(_ window: NSWindow?) {
        guard let window, window.canBecomeKey else { return }
        HubShelfWindowStyle.apply(to: window)
        hubWindow = window
    }

    func setOpenHubAction(_ action: @escaping () -> Void) {
        openHubAction = action
    }

    func openHub() {
        hubRequestedVisible = true
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)
        NotificationCenter.default.post(name: .edisonHubWillOpen, object: nil)

        if let targetWindow = resolveHubWindow(preferVisible: false) {
            HubShelfWindowStyle.apply(to: targetWindow)
            if targetWindow.isMiniaturized { targetWindow.deminiaturize(nil) }

            if !targetWindow.isVisible {
                animateWindowIn(targetWindow)
            } else {
                targetWindow.makeKeyAndOrderFront(nil)
                targetWindow.orderFrontRegardless()
                targetWindow.makeFirstResponder(nil)
            }
            return
        }

        openHubAction?()
        DispatchQueue.main.async {
            guard let hubWindow = self.resolveHubWindow(preferVisible: false) else { return }
            HubShelfWindowStyle.apply(to: hubWindow)
            self.animateWindowIn(hubWindow)
        }
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func dismissHub() {
        hubRequestedVisible = false
        let windows = hubWindows()
        guard !windows.isEmpty else {
            hubWindow?.orderOut(nil)
            return
        }

        for window in windows {
            animateWindowOut(window)
        }
    }

    func adjustShelfHeight(by delta: CGFloat) {
        guard let window = resolveHubWindow() else { return }
        let currentHeight = window.frame.height
        let newHeight = min(Self.maxShelfHeight, max(Self.minShelfHeight, currentHeight - delta))
        guard abs(newHeight - currentHeight) > 0.5 else { return }

        let newOriginY = window.frame.maxY - newHeight
        var newFrame = window.frame
        newFrame.origin.y = newOriginY
        newFrame.size.height = newHeight
        window.setFrame(newFrame, display: true, animate: false)
        storedShelfHeight = newHeight
    }

    private var isHubPresented: Bool {
        if hubWindows().contains(where: isWindowPresented(_:)) {
            return true
        }
        return hubRequestedVisible
    }

    private func hubWindows() -> [NSWindow] {
        var candidates: [NSWindow] = []
        let appWindows = NSApp.windows

        if let hubWindow, appWindows.contains(hubWindow) {
            candidates.append(hubWindow)
        }

        for window in appWindows where matchesHubWindow(window) {
            if candidates.contains(where: { $0 === window }) {
                continue
            }
            candidates.append(window)
        }

        return candidates
    }

    private func resolveHubWindow(preferVisible: Bool = true) -> NSWindow? {
        let candidates = hubWindows()

        if preferVisible,
           let visibleWindow = candidates.first(where: isWindowPresented(_:)) {
            hubWindow = visibleWindow
            return visibleWindow
        }

        if let keyedWindow = candidates.first(where: \.isKeyWindow) {
            hubWindow = keyedWindow
            return keyedWindow
        }

        if let identifiedWindow = candidates.first(where: { $0.identifier?.rawValue == "hub-window" && $0.canBecomeKey }) {
            hubWindow = identifiedWindow
            return identifiedWindow
        }

        if let titledWindow = candidates.first(where: { $0.title == "Edison" && $0.canBecomeKey }) {
            hubWindow = titledWindow
            return titledWindow
        }

        let fallback = NSApp.windows.first { $0.canBecomeKey && !($0 is NSPanel) }
        if let fallback {
            hubWindow = fallback
        }
        return fallback
    }

    private func animateWindowIn(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let finalFrame = window.frame
        var startFrame = finalFrame
        startFrame.origin.y = screen.frame.minY - finalFrame.height

        window.setFrame(startFrame, display: false)
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(finalFrame, display: true)
        } completionHandler: {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(nil)
        }
    }

    private func animateWindowOut(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else {
            window.orderOut(nil)
            return
        }

        let startFrame = window.frame
        var endFrame = startFrame
        endFrame.origin.y = screen.frame.minY - startFrame.height

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(endFrame, display: true)
        } completionHandler: {
            window.orderOut(nil)
            window.setFrame(startFrame, display: false)
        }
    }

    private func matchesHubWindow(_ window: NSWindow) -> Bool {
        guard window.canBecomeKey else { return false }
        if window.identifier?.rawValue == "hub-window" {
            return true
        }
        if window === hubWindow {
            return true
        }
        return window.title == "Edison"
    }

    private func isWindowPresented(_ window: NSWindow) -> Bool {
        window.isVisible || window.occlusionState.contains(.visible) || window.isKeyWindow
    }
}

extension Notification.Name {
    static let edisonHubWillOpen = Notification.Name("edison.hub.will-open")
}
