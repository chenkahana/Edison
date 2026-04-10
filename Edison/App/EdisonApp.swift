import SwiftUI

@main
struct EdisonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("Edison", id: "hub") {
            HubView()
                .environmentObject(appState)
                .onAppear {
                    appState.windowRouter = appDelegate.windowRouter
                }
        }
        .defaultSize(width: HubTheme.shelfWindowSize.width, height: HubTheme.shelfWindowSize.height)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
