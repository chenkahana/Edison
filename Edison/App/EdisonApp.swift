import SwiftUI

@main
struct EdisonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        Window("Edison", id: "hub") {
            HubView()
                .environmentObject(appState)
                .onAppear {
                    appState.windowRouter = appDelegate.windowRouter
                }
        }
        .defaultSize(width: HubTheme.shelfWindowSize.width, height: HubTheme.shelfWindowSize.height)
        .windowStyle(.hiddenTitleBar)

        Window("Screenshot Editor", id: "editor") {
            EditorWindowView()
                .environmentObject(appState)
                .onAppear {
                    appState.windowRouter = appDelegate.windowRouter
                }
        }
        .defaultSize(width: 1120, height: 760)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
