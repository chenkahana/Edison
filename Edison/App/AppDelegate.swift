import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowRouter = WindowRouter()
    private var statusController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusController = StatusBarController(
            actions: .init(
                openHub: { [weak self] in
                    self?.windowRouter.openHub()
                },
                captureArea: {
                    NotificationCenter.default.post(
                        name: .edisonShortcutActionRequested,
                        object: ShortcutAction.captureArea.rawValue
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
                openSettings: { [weak self] in
                    self?.windowRouter.openSettings()
                },
                quit: {
                    NSApp.terminate(nil)
                }
            )
        )
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
