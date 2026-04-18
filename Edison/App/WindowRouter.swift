import AppKit

@MainActor
final class WindowRouter {
    private weak var hubWindow: NSWindow?
    private weak var storedEditorWindow: NSWindow?
    private var openHubAction: (() -> Void)?
    private var openEditorAction: (() -> Void)?
    private var hubRequestedVisible = false

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

        guard hubRequestedVisible else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        if !isWindowPresented(window) {
            animateWindowIn(window)
        } else {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    func setOpenHubAction(_ action: @escaping () -> Void) {
        openHubAction = action
    }

    func setOpenEditorAction(_ action: @escaping () -> Void) {
        openEditorAction = action
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
            }
            return
        }

        openHubAction?()
        DispatchQueue.main.async {
            guard let hubWindow = self.resolveHubWindow(preferVisible: false) else { return }
            HubShelfWindowStyle.apply(to: hubWindow)
            if hubWindow.isVisible {
                hubWindow.makeKeyAndOrderFront(nil)
                hubWindow.orderFrontRegardless()
            } else {
                self.animateWindowIn(hubWindow)
            }
        }
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    var editorWindow: NSWindow? {
        resolveEditorWindow()
    }

    func registerEditorWindow(_ window: NSWindow?) {
        guard let window else { return }
        window.identifier = NSUserInterfaceItemIdentifier("editor-window")
        storedEditorWindow = window
    }

    func openEditor() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)

        if let editorWindow = resolveEditorWindow() {
            if editorWindow.isMiniaturized {
                editorWindow.deminiaturize(nil)
            }
            editorWindow.makeKeyAndOrderFront(nil)
            editorWindow.orderFrontRegardless()
            return
        }

        openEditorAction?()
        DispatchQueue.main.async {
            guard let editorWindow = self.resolveEditorWindow() else { return }
            editorWindow.makeKeyAndOrderFront(nil)
            editorWindow.orderFrontRegardless()
        }
    }

    func dismissEditor() {
        resolveEditorWindow()?.orderOut(nil)
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

    func dismissHubImmediately() {
        hubRequestedVisible = false
        let windows = hubWindows()
        guard !windows.isEmpty else {
            hubWindow?.orderOut(nil)
            return
        }

        for window in windows {
            window.orderOut(nil)
        }
    }

    func dismissHubForPasteBack() {
        dismissHubImmediately()
        NSApp.hide(nil)
    }

    var isHubPresented: Bool {
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

    private func resolveEditorWindow() -> NSWindow? {
        if let storedEditorWindow, NSApp.windows.contains(storedEditorWindow) {
            return storedEditorWindow
        }

        let fallback = NSApp.windows.first { $0.identifier?.rawValue == "editor-window" }
        if let fallback {
            storedEditorWindow = fallback
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
        startFrame.origin.y = screen.visibleFrame.minY - finalFrame.height

        window.setFrame(startFrame, display: false)
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(finalFrame, display: true)
        } completionHandler: {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func animateWindowOut(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else {
            window.orderOut(nil)
            return
        }

        let startFrame = window.frame
        var endFrame = startFrame
        endFrame.origin.y = screen.visibleFrame.minY - startFrame.height

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
