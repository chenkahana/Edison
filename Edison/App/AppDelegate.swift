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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        TemporaryFiles.purgeAll()
        appState.windowRouter = windowRouter
        windowRouter.setOpenHubAction { [weak self] in self?.makeHubWindow() }
        windowRouter.setOpenEditorAction { [weak self] in self?.makeEditorWindow() }
        statusController = StatusBarController(
            actions: .init(
                openHub: { [weak self] in
                    self?.windowRouter.openHub()
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
                editLastScreenshot: {
                    NotificationCenter.default.post(
                        name: .edisonShortcutActionRequested,
                        object: ShortcutAction.editLastScreenshot.rawValue
                    )
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
                }
            )
        )
    }

    private func makeHubWindow() {
        guard hubWindow == nil else { return }
        let window = makeWindow(
            rootView: HubView(),
            styleMask: [.titled, .fullSizeContentView],
            size: HubTheme.shelfWindowSize
        )
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

    private func makeWindow<Content: View>(rootView: Content, styleMask: NSWindow.StyleMask, size: NSSize) -> NSWindow {
        let controller = NSHostingController(rootView: rootView.environmentObject(appState))
        controller.sizingOptions = []
        let window = NSWindow(contentViewController: controller)
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
