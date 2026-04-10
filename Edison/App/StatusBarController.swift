import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let windowRouter: WindowRouter

    init(windowRouter: WindowRouter) {
        self.windowRouter = windowRouter
        super.init()
        constructMenu()
    }

    private func constructMenu() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: "Edison")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Hub", action: #selector(openHub), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Capture", action: #selector(capture), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func openHub() {
        windowRouter.openHub()
    }

    @objc private func openSettings() {
        windowRouter.openSettings()
    }

    @objc private func capture() {
        // Capture flow is intentionally a shell-only placeholder for this task.
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
