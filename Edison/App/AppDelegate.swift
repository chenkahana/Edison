import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowRouter = WindowRouter()
    private var statusController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusController = StatusBarController(windowRouter: windowRouter)
    }
}
