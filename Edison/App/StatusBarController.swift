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
        let toggleHistoryPause: () -> Void
        let openSettings: () -> Void
        let quit: () -> Void
        /// Nil in builds without Sparkle (`swift build`), which have no updater.
        var checkForUpdates: (() -> Void)?
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let actions: Actions
    private let pauseItem = NSMenuItem(title: "Pause Clipboard History", action: nil, keyEquivalent: "")
    private var pauseObserver: NSObjectProtocol?

    init(actions: Actions) {
        self.actions = actions
        super.init()
        constructMenu()
        pauseObserver = NotificationCenter.default.addObserver(
            forName: .edisonHistoryPauseChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let paused = (note.object as? Bool) ?? false
            MainActor.assumeIsolated {
                self?.reflectPause(paused)
            }
        }
    }

    private func reflectPause(_ paused: Bool) {
        pauseItem.title = paused ? "Resume Clipboard History" : "Pause Clipboard History"
        pauseItem.state = paused ? .on : .off
        // A dimmed menu-bar icon makes a paused history obvious at a glance.
        statusItem.button?.appearsDisabled = paused
        statusItem.button?.toolTip = paused ? "Edison — clipboard history paused" : "Edison"
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
        pauseItem.action = #selector(toggleHistoryPause)
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        if actions.checkForUpdates != nil {
            menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: ""))
        }
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

    @objc private func toggleHistoryPause() {
        actions.toggleHistoryPause()
    }

    @objc private func checkForUpdates() {
        actions.checkForUpdates?()
    }

    @objc private func quit() {
        actions.quit()
    }
}
