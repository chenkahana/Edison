import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowRouter = WindowRouter()
    private var statusController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusController = StatusBarController(windowRouter: windowRouter)
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
