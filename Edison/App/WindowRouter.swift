import AppKit

@MainActor
final class WindowRouter {
    private weak var hubWindow: NSWindow?

    func registerHubWindow(_ window: NSWindow?) {
        guard let window, window.canBecomeKey else { return }
        hubWindow = window
    }

    func openHub() {
        NSApp.activate(ignoringOtherApps: true)
        if let targetWindow = resolveHubWindow() {
            if targetWindow.isMiniaturized {
                targetWindow.deminiaturize(nil)
            }
            targetWindow.makeKeyAndOrderFront(nil)
            targetWindow.orderFrontRegardless()
            return
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
