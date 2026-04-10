import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let windowRouter: WindowRouter
    private let captureEngine = CaptureEngine()

    init(windowRouter: WindowRouter) {
        self.windowRouter = windowRouter
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
        menu.addItem(NSMenuItem(title: "Open Edison", action: #selector(openHub), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Capture Area", action: #selector(captureArea), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Window", action: #selector(captureWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Full Screen", action: #selector(captureFullScreen), keyEquivalent: ""))
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

    @objc private func captureArea() {
        captureEngine.captureArea()
    }

    @objc private func captureWindow() {
        captureEngine.captureWindow()
    }

    @objc private func captureFullScreen() {
        captureEngine.captureFullScreen()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
