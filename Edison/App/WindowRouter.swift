import AppKit

@MainActor
final class WindowRouter {
    private weak var hubWindow: NSWindow?
    private var openHubAction: (() -> Void)?

    func registerHubWindow(_ window: NSWindow?) {
        guard let window, window.canBecomeKey else { return }
        HubShelfWindowStyle.apply(to: window)
        hubWindow = window
    }

    func setOpenHubAction(_ action: @escaping () -> Void) {
        openHubAction = action
    }

    func openHub() {
        NSApp.activate(ignoringOtherApps: true)
        if let targetWindow = resolveHubWindow() {
            HubShelfWindowStyle.apply(to: targetWindow)
            if targetWindow.isMiniaturized {
                targetWindow.deminiaturize(nil)
            }
            targetWindow.makeKeyAndOrderFront(nil)
            targetWindow.orderFrontRegardless()
            return
        }

        openHubAction?()

        DispatchQueue.main.async {
            guard let hubWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "hub-window" }) else { return }
            HubShelfWindowStyle.apply(to: hubWindow)
            hubWindow.makeKeyAndOrderFront(nil)
        }

        NSApp.unhide(nil)
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func resolveHubWindow() -> NSWindow? {
        if let hubWindow, NSApp.windows.contains(hubWindow) {
            return hubWindow
        }

        let identifiedWindow = NSApp.windows.first {
            $0.identifier?.rawValue == "hub-window" && $0.canBecomeKey
        }
        if let identifiedWindow {
            hubWindow = identifiedWindow
            return identifiedWindow
        }

        let primaryCandidate = NSApp.windows.first {
            $0.title == "Edison" && $0.canBecomeKey
        }
        if let primaryCandidate {
            hubWindow = primaryCandidate
            return primaryCandidate
        }

        let fallback = NSApp.windows.first {
            $0.canBecomeKey && !($0 is NSPanel)
        }
        if let fallback {
            hubWindow = fallback
        }
        return fallback
    }
}
