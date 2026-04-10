import AppKit

@MainActor
final class WindowRouter {
    private var openHubAction: (() -> Void)?

    func setOpenHubAction(_ action: @escaping () -> Void) {
        openHubAction = action
    }

    func openHub() {
        NSApp.activate(ignoringOtherApps: true)
        if let hubWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "hub-window" }) {
            hubWindow.makeKeyAndOrderFront(nil)
            return
        }

        openHubAction?()

        DispatchQueue.main.async {
            NSApp.windows.first(where: { $0.identifier?.rawValue == "hub-window" })?.makeKeyAndOrderFront(nil)
        }
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
