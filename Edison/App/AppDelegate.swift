import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowRouter = WindowRouter()
    lazy var appState = AppState()
    private var statusController: StatusBarController?
    // The Hub and editor are AppKit-owned so they can always be opened; SwiftUI only creates
    // scene windows when it chooses to, which left the app with no window to show.
    private var hubWindow: NSWindow?
    private var editorWindow: NSWindow?
    private var firstRunWindow: NSWindow?
    private let firstRunDoneKey = "edison.firstRun.done"
    #if SPARKLE
    private let updater = Updater()
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        TemporaryFiles.purgeAll()
        appState.windowRouter = windowRouter
        windowRouter.setOpenHubAction { [weak self] in self?.makeHubWindow() }
        windowRouter.setOpenEditorAction { [weak self] in self?.makeEditorWindow() }
        showFirstRunIfNeeded()
        statusController = StatusBarController(
            actions: .init(
                openHub: {
                    // Same path as the shortcut: toggles, and remembers the app to paste back into.
                    NotificationCenter.default.post(
                        name: .edisonShortcutActionRequested,
                        object: ShortcutAction.openHub.rawValue
                    )
                },
                captureScreenshot: {
                    NotificationCenter.default.post(
                        name: .edisonShortcutActionRequested,
                        object: ShortcutAction.captureScreenshot.rawValue
                    )
                },
                captureWindow: {
                    NotificationCenter.default.post(
                        name: .edisonShortcutActionRequested,
                        object: ShortcutAction.captureWindow.rawValue
                    )
                },
                captureFullScreen: {
                    NotificationCenter.default.post(
                        name: .edisonShortcutActionRequested,
                        object: ShortcutAction.captureFullScreen.rawValue
                    )
                },
                capturePreviousArea: {
                    NotificationCenter.default.post(
                        name: .edisonShortcutActionRequested,
                        object: ShortcutAction.capturePreviousArea.rawValue
                    )
                },
                canCapturePreviousArea: { [weak self] in
                    self?.appState.canCapturePreviousArea ?? false
                },
                editLastScreenshot: {
                    NotificationCenter.default.post(
                        name: .edisonShortcutActionRequested,
                        object: ShortcutAction.editLastScreenshot.rawValue
                    )
                },
                canEditLastScreenshot: { [weak self] in
                    self?.appState.lastScreenshotSession != nil
                },
                toggleHistoryPause: {
                    NotificationCenter.default.post(
                        name: .edisonShortcutActionRequested,
                        object: ShortcutAction.toggleHistoryPause.rawValue
                    )
                },
                openSettings: { [weak self] in
                    self?.windowRouter.openSettings()
                },
                quit: {
                    NSApp.terminate(nil)
                },
                shortcuts: { [weak self] in
                    self?.appState.shortcutStore.current ?? .default
                },
                checkForUpdates: checkForUpdatesAction
            )
        )
    }

    private var checkForUpdatesAction: (() -> Void)? {
        #if SPARKLE
        return { [weak self] in self?.updater.checkForUpdates() }
        #else
        return nil
        #endif
    }

    private func makeHubWindow() {
        guard hubWindow == nil else { return }
        // A non-activating panel takes keys without activating Edison, so the app you were in stays
        // active: its selection stays lit and paste-back needs no re-activation.
        let window = HubPanel(
            contentRect: NSRect(origin: .zero, size: HubTheme.shelfWindowSize),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = makeHostingController(rootView: HubView())
        window.setContentSize(HubTheme.shelfWindowSize)
        window.isReleasedWhenClosed = false
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = false
        window.title = "Edison"
        HubShelfWindowStyle.apply(to: window)
        hubWindow = window
    }

    private func makeEditorWindow() {
        guard editorWindow == nil else { return }
        let window = makeWindow(
            rootView: EditorWindowView(),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            size: NSSize(width: 1120, height: 760)
        )
        window.title = "Screenshot Editor"
        window.identifier = NSUserInterfaceItemIdentifier("editor-window")
        window.minSize = NSSize(width: 920, height: 620)
        window.center()
        window.setFrameAutosaveName("EdisonScreenshotEditor")
        editorWindow = window
    }

    /// New installs get one welcome window. Anyone with history already knows Edison, so they never see it.
    private func showFirstRunIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: firstRunDoneKey) else { return }
        let historyFile = HistoryStore.storageDirectory.appendingPathComponent("history.json")
        guard !FileManager.default.fileExists(atPath: historyFile.path) else {
            defaults.set(true, forKey: firstRunDoneKey)
            return
        }

        let window = makeWindow(
            rootView: FirstRunView { [weak self] in
                guard let self else { return }
                UserDefaults.standard.set(true, forKey: self.firstRunDoneKey)
                self.firstRunWindow?.close()
                self.firstRunWindow = nil
            },
            // No close button: Done is the one way out, so finishing is never mistaken for skipping.
            styleMask: [.titled],
            size: NSSize(width: 460, height: 400)
        )
        window.title = "Welcome to Edison"
        sizeToFitContent(window)
        window.center()
        firstRunWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func sizeToFitContent(_ window: NSWindow) {
        if let size = window.contentViewController?.view.fittingSize, size.height > 0 {
            window.setContentSize(size)
        }
    }

    private func makeHostingController<Content: View>(rootView: Content) -> NSViewController {
        let controller = NSHostingController(rootView: rootView.environmentObject(appState))
        controller.sizingOptions = []
        return controller
    }

    private func makeWindow<Content: View>(rootView: Content, styleMask: NSWindow.StyleMask, size: NSSize) -> NSWindow {
        let window = NSWindow(contentViewController: makeHostingController(rootView: rootView))
        window.styleMask = styleMask
        window.setContentSize(size)
        window.isReleasedWhenClosed = false
        return window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return false }
        windowRouter.openHub()
        return true
    }
}

/// The Hub's window. A non-activating panel still becomes key so search and the arrow keys work.
final class HubPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
