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
            }

            Section("About") {
                LabeledContent("Bundle Identifier", value: Bundle.main.bundleIdentifier ?? "com.your-company.Edison")
                Text("Replace placeholder bundle id before shipping.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
