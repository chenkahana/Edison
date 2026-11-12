import SwiftUI

@main
struct EdisonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // The Hub and screenshot editor windows are created by AppDelegate (see WindowRouter).
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}
