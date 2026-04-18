import AppKit

@MainActor
final class StatusBarController: NSObject {
    struct Actions {
        let openHub: () -> Void
        let captureScreenshot: () -> Void
        let captureWindow: () -> Void
        let captureFullScreen: () -> Void
        let capturePreviousArea: () -> Void
        let editLastScreenshot: () -> Void
        let openSettings: () -> Void
        let quit: () -> Void
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let actions: Actions

    init(actions: Actions) {
        self.actions = actions
        super.init()
        constructMenu()
    }

    private func constructMenu() {
        if let button = statusItem.button {
            let image = NSImage(named: "menubarIcon") ?? NSImage(systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: "Edison")
            image?.isTemplate = true
            image?.size = NSSize(width: 18, height: 18)
            button.image = image
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Hub", action: #selector(openHub), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Capture Screenshot", action: #selector(captureScreenshot), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Window", action: #selector(captureWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Full Screen", action: #selector(captureFullScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Previous Area", action: #selector(capturePreviousArea), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Edit Last Screenshot", action: #selector(editLastScreenshot), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func openHub() {
        actions.openHub()
    }

    @objc private func openSettings() {
        actions.openSettings()
    }

    @objc private func captureScreenshot() {
        actions.captureScreenshot()
    }

    @objc private func captureWindow() {
        actions.captureWindow()
    }

    @objc private func captureFullScreen() {
        actions.captureFullScreen()
    }

    @objc private func capturePreviousArea() {
        actions.capturePreviousArea()
    }

    @objc private func editLastScreenshot() {
        actions.editLastScreenshot()
    }

    @objc private func quit() {
        actions.quit()
    }
}
