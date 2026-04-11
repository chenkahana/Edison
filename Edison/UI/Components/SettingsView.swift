import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var editableShortcuts: ShortcutSet = .default

    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                ForEach(ShortcutAction.allCases) { action in
                    ShortcutEditorRow(action: action, shortcut: binding(for: action))
                }

                Button("Save Shortcuts") {
                    appState.save(shortcuts: editableShortcuts)
                }

                if !appState.failedShortcutActions.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                        Text("Some shortcuts couldn't be registered — they may conflict with another app.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if appState.accessibilityDenied {
                Section("Paste Back") {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                        Text("Accessibility access is required to paste items automatically into other apps.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button("Grant Accessibility Access") {
                        appState.requestAccessibilityAccess()
                    }
                }
            }

            Section("About") {
                LabeledContent("App", value: Bundle.main.edisonDisplayName)
                LabeledContent("Version", value: Bundle.main.edisonShortVersion)
                LabeledContent("Build", value: Bundle.main.edisonBuildNumber)
                LabeledContent("Bundle Identifier", value: Bundle.main.bundleIdentifier ?? "Unavailable")
            }
        }
        .padding()
        .frame(width: 620)
        .onAppear {
            editableShortcuts = appState.shortcutStore.current
        }
    }

    private func binding(for action: ShortcutAction) -> Binding<Shortcut> {
        Binding(
            get: { editableShortcuts[action] },
            set: { editableShortcuts[action] = $0 }
        )
    }
}

private extension Bundle {
    var edisonDisplayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? "Edison"
    }

    var edisonShortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    var edisonBuildNumber: String {
        object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "Unknown"
    }
}
