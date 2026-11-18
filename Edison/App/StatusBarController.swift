import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    struct Actions {
        let openHub: () -> Void
        let captureScreenshot: () -> Void
        let captureWindow: () -> Void
        let captureFullScreen: () -> Void
        let capturePreviousArea: () -> Void
        let canCapturePreviousArea: () -> Bool
        let editLastScreenshot: () -> Void
        let canEditLastScreenshot: () -> Bool
        let toggleHistoryPause: () -> Void
        let openSettings: () -> Void
        let quit: () -> Void
        let shortcuts: () -> ShortcutSet
        /// Nil in builds without Sparkle (`swift build`), which have no updater.
        var checkForUpdates: (() -> Void)?
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let actions: Actions
    private let pauseItem = NSMenuItem(title: "Pause Clipboard History", action: nil, keyEquivalent: "")
    private var pauseObserver: NSObjectProtocol?
    private var shortcutItems: [ShortcutAction: NSMenuItem] = [:]

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
        menu.addItem(shortcutItem("Open Hub", #selector(openHub), .openHub))
        menu.addItem(.separator())
        menu.addItem(shortcutItem("Capture Screenshot", #selector(captureScreenshot), .captureScreenshot))
        menu.addItem(shortcutItem("Capture Window", #selector(captureWindow), .captureWindow))
        menu.addItem(shortcutItem("Capture Full Screen", #selector(captureFullScreen), .captureFullScreen))
        menu.addItem(shortcutItem("Capture Previous Area", #selector(capturePreviousArea), .capturePreviousArea))
        menu.addItem(shortcutItem("Edit Last Screenshot", #selector(editLastScreenshot), .editLastScreenshot))
        menu.addItem(.separator())
        pauseItem.action = #selector(toggleHistoryPause)
        shortcutItems[.toggleHistoryPause] = pauseItem
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        if actions.checkForUpdates != nil {
            menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem(title: "Quit Edison", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        menu.delegate = self
        statusItem.menu = menu
    }

    private func shortcutItem(_ title: String, _ action: Selector, _ shortcutAction: ShortcutAction) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        shortcutItems[shortcutAction] = item
        return item
    }

    /// Shows each action's global shortcut next to it, so the menu teaches the keys.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let shortcuts = actions.shortcuts()
        for (action, item) in shortcutItems {
            let shortcut = shortcuts[action]
            item.keyEquivalent = shortcut?.menuKeyEquivalent ?? ""
            item.keyEquivalentModifierMask = shortcut?.menuModifierFlags ?? []
        }
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

extension StatusBarController: NSMenuItemValidation {
    /// Items with nothing to act on are disabled instead of failing silently.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(capturePreviousArea):
            actions.canCapturePreviousArea()
        case #selector(editLastScreenshot):
            actions.canEditLastScreenshot()
        default:
            true
        }
    }
}
