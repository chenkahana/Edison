import AppKit

@MainActor
final class WindowRouter {
    func openHub() {
        NSApp.activate(ignoringOtherApps: true)
        if let hubWindow = NSApp.windows.first {
            hubWindow.makeKeyAndOrderFront(nil)
        }
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
