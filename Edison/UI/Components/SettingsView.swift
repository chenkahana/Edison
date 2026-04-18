import AppKit
import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case capture
    case editor
    case privacy
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .shortcuts: return "Keyboard Shortcuts"
        case .capture: return "Capture"
        case .editor: return "Editor"
        case .privacy: return "Storage & Privacy"
        case .permissions: return "Permissions & Support"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .shortcuts: return "keyboard"
        case .capture: return "camera.viewfinder"
        case .editor: return "slider.horizontal.3"
        case .privacy: return "externaldrive"
        case .permissions: return "hand.raised"
        case .about: return "info.circle"
        }
    }

    var keywords: [String] {
        switch self {
        case .general: return ["launch", "login", "startup"]
        case .shortcuts: return ["keyboard", "hotkey", "shortcut"]
        case .capture: return ["screenshot", "save folder", "filename"]
        case .editor: return ["annotation", "blur", "style", "window size"]
        case .privacy: return ["history", "storage", "clear", "local"]
        case .permissions: return ["screen recording", "accessibility", "diagnostics", "support"]
        case .about: return ["version", "build", "bundle"]
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedPane: SettingsPane? = .general
    @State private var searchQuery = ""
    @State private var editableSettings = AppSettings.default
    @State private var editableShortcuts = ShortcutSet.default
    @State private var isBootstrapping = true
    @State private var storageUsageDescription = "Calculating..."

    private var filteredPanes: [SettingsPane] {
        let normalized = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return SettingsPane.allCases }
        return SettingsPane.allCases.filter { pane in
            pane.title.lowercased().contains(normalized) || pane.keywords.contains(where: { $0.contains(normalized) })
        }
    }

    private var shortcutIssues: [ShortcutAction: [ShortcutValidationIssue]] {
        ShortcutValidator.validationIssues(for: editableShortcuts)
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: HubTheme.Space.x3) {
                TextField("Search Settings", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)

                List(filteredPanes, selection: $selectedPane) { pane in
                    Label(pane.title, systemImage: pane.icon)
                        .tag(Optional(pane))
                }
                .listStyle(.sidebar)

                HStack {
                    Button("Restore All Defaults") {
                        editableSettings = .default
                        editableShortcuts = .default
                        appState.restoreDefaultSettings()
                        appState.save(shortcuts: .default)
                    }
                    Spacer()
                }
            }
            .padding(HubTheme.Space.x4)
            .frame(minWidth: 240)
        } detail: {
            ScrollView {
                detailView(for: selectedPane ?? filteredPanes.first ?? .general)
                    .padding(HubTheme.Space.x5)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(HubGlassBackground())
        }
        .frame(width: 960, height: 720)
        .onAppear {
            editableSettings = appState.settings
            editableShortcuts = appState.shortcutStore.current
            appState.refreshPermissionStatuses()
            refreshStorageUsage()
            isBootstrapping = false
        }
        .onChange(of: editableSettings) { _, newValue in
            guard !isBootstrapping else { return }
            appState.save(settings: newValue)
            refreshStorageUsage()
        }
        .onChange(of: editableShortcuts) { _, newValue in
            guard !isBootstrapping else { return }
            if shortcutIssues.isEmpty {
                appState.save(shortcuts: newValue)
            }
        }
    }

    @ViewBuilder
    private func detailView(for pane: SettingsPane) -> some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x4) {
            HStack {
                Label(pane.title, systemImage: pane.icon)
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Restore Defaults") {
                    restoreDefaults(for: pane)
                }
            }

            switch pane {
            case .general:
                generalPane
            case .shortcuts:
                shortcutsPane
            case .capture:
                capturePane
            case .editor:
                editorPane
            case .privacy:
                privacyPane
            case .permissions:
                permissionsPane
            case .about:
                aboutPane
            }
        }
    }

    private var generalPane: some View {
        Form {
            Toggle("Launch at Login", isOn: Binding(
                get: { editableSettings.general.launchAtLogin },
                set: { editableSettings.general.launchAtLogin = $0 }
            ))

            Toggle("Start Hidden When Launched at Login", isOn: Binding(
                get: { editableSettings.general.startHiddenWhenLaunchedAtLogin },
                set: { editableSettings.general.startHiddenWhenLaunchedAtLogin = $0 }
            ))

            LabeledContent("Launch at Login Status", value: appState.launchAtLoginStatusDescription)

            if let error = appState.launchAtLoginErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutsPane: some View {
        Form {
            Section("Shortcut Bindings") {
                ForEach(ShortcutAction.allCases) { action in
                    ShortcutEditorRow(
                        action: action,
                        shortcut: shortcutBinding(for: action),
                        validationIssues: shortcutIssues[action] ?? [],
                        failedRegistration: appState.failedShortcutActions.contains(action),
                        restoreDefault: {
                            editableShortcuts[action] = ShortcutSet.defaultShortcut(for: action)
                        }
                    )
                }
            }

            if !shortcutIssues.isEmpty {
                Section {
                    Text("Shortcut changes apply automatically once Edison's conflicts and reserved shortcuts are resolved.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var capturePane: some View {
        Form {
            Toggle("Open Editor After Capture", isOn: Binding(
                get: { editableSettings.capture.openEditorAfterCapture },
                set: { editableSettings.capture.openEditorAfterCapture = $0 }
            ))
            Toggle("Remember Last Area", isOn: Binding(
                get: { editableSettings.capture.rememberLastArea },
                set: { editableSettings.capture.rememberLastArea = $0 }
            ))
            Toggle("Show Magnifier and Dimensions", isOn: Binding(
                get: { editableSettings.capture.showMagnifierAndDimensions },
                set: { editableSettings.capture.showMagnifierAndDimensions = $0 }
            ))

            Picker("Default Result", selection: Binding(
                get: { editableSettings.capture.defaultResult },
                set: { editableSettings.capture.defaultResult = $0 }
            )) {
                ForEach(CaptureDefaultResult.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

            LabeledContent("Default Save Folder") {
                HStack {
                    Text(editableSettings.capture.defaultSaveFolderPath ?? "Ask Every Time")
                        .foregroundStyle(.secondary)
                    Button("Choose…", action: chooseDefaultSaveFolder)
                    if editableSettings.capture.defaultSaveFolderPath != nil {
                        Button("Clear") {
                            editableSettings.capture.defaultSaveFolderPath = nil
                        }
                    }
                }
            }

            TextField("Filename Template", text: Binding(
                get: { editableSettings.capture.filenameTemplate },
                set: { editableSettings.capture.filenameTemplate = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Text("Use `{date}` and `{time}` in the filename template.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var editorPane: some View {
        Form {
            Toggle("Close After Copy or Save", isOn: Binding(
                get: { editableSettings.editor.closeAfterCopySave },
                set: { editableSettings.editor.closeAfterCopySave = $0 }
            ))
            Toggle("Remember Window Size", isOn: Binding(
                get: { editableSettings.editor.rememberWindowSize },
                set: { editableSettings.editor.rememberWindowSize = $0 }
            ))

            Section("Default Annotation Style") {
                editorStyleStepper("Stroke Width", value: editableSettings.editor.defaultStyle.lineWidth, range: 1...24) {
                    editableSettings.editor.defaultStyle.lineWidth = $0
                }
                editorStyleStepper("Font Size", value: editableSettings.editor.defaultStyle.fontSize, range: 14...96) {
                    editableSettings.editor.defaultStyle.fontSize = $0
                }
                editorStyleStepper("Blur Strength", value: editableSettings.editor.defaultStyle.blurRadius, range: 4...40) {
                    editableSettings.editor.defaultStyle.blurRadius = $0
                }
            }
        }
        .formStyle(.grouped)
    }

    private var privacyPane: some View {
        Form {
            Stepper(
                "History Limit: \(editableSettings.privacy.historyLimit)",
                value: Binding(
                    get: { editableSettings.privacy.historyLimit },
                    set: { editableSettings.privacy.historyLimit = max(25, min($0, 1000)) }
                ),
                in: 25...1000,
                step: 25
            )

            LabeledContent("Storage Usage", value: storageUsageDescription)

            HStack {
                Button("Reveal Storage Folder") {
                    appState.revealStorageFolder()
                }
                Button("Clear History", role: .destructive) {
                    appState.clearHistory()
                    refreshStorageUsage()
                }
            }

            Text("Edison stores clipboard history and screenshots locally on this Mac. No cloud sync or upload service is enabled in this release.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var permissionsPane: some View {
        Form {
            statusCard(
                title: "Screen Recording",
                isGranted: appState.screenRecordingAccessGranted,
                description: "Required for screenshot capture."
            ) {
                appState.requestScreenRecordingAccess()
            }

            statusCard(
                title: "Accessibility",
                isGranted: AXIsProcessTrusted(),
                description: "Needed only for direct paste-back into other apps."
            ) {
                appState.requestAccessibilityAccess()
            }

            LabeledContent("Last Capture Failure", value: appState.lastCaptureFailureReason ?? "None")

            HStack {
                Button("Refresh Status") {
                    appState.refreshPermissionStatuses()
                }
                Button("Export Diagnostics") {
                    appState.exportDiagnostics()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var aboutPane: some View {
        Form {
            LabeledContent("App", value: Bundle.main.edisonDisplayName)
            LabeledContent("Version", value: Bundle.main.edisonShortVersion)
            LabeledContent("Build", value: Bundle.main.edisonBuildNumber)
            LabeledContent("Bundle Identifier", value: Bundle.main.bundleIdentifier ?? "Unavailable")
        }
        .formStyle(.grouped)
    }

    private func restoreDefaults(for pane: SettingsPane) {
        switch pane {
        case .general:
            editableSettings.general = AppSettings.default.general
        case .shortcuts:
            editableShortcuts = .default
            appState.save(shortcuts: .default)
        case .capture:
            editableSettings.capture = AppSettings.default.capture
        case .editor:
            editableSettings.editor = AppSettings.default.editor
        case .privacy:
            editableSettings.privacy = AppSettings.default.privacy
        case .permissions:
            appState.refreshPermissionStatuses()
        case .about:
            break
        }
    }

    private func shortcutBinding(for action: ShortcutAction) -> Binding<Shortcut?> {
        Binding(
            get: { editableShortcuts[action] },
            set: { editableShortcuts[action] = $0 }
        )
    }

    private func chooseDefaultSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            editableSettings.capture.defaultSaveFolderPath = panel.url?.path
        }
    }

    private func editorStyleStepper(_ title: String, value: Double, range: ClosedRange<Double>, set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(
                "\(Int(value.rounded()))",
                value: Binding(
                    get: { value },
                    set: { set(min(max($0, range.lowerBound), range.upperBound)) }
                ),
                in: range
            )
            .labelsHidden()
        }
    }

    private func statusCard(title: String, isGranted: Bool, description: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
            HStack {
                Label(title, systemImage: isGranted ? "checkmark.shield" : "exclamationmark.triangle")
                    .font(.headline)
                Spacer()
                Text(isGranted ? "Enabled" : "Needs Attention")
                    .foregroundStyle(isGranted ? .green : .orange)
            }
            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(isGranted ? "Open Settings" : "Fix Access", action: action)
        }
        .padding(HubTheme.Space.x4)
        .background(HubTheme.cardFillMuted, in: RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous))
    }

    private func refreshStorageUsage() {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        storageUsageDescription = formatter.string(fromByteCount: Int64(directorySize(at: HistoryStore.storageDirectory)))
    }

    private func directorySize(at url: URL) -> Int {
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(resourceKeys))
        var total = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys),
                  values.isDirectory != true else {
                continue
            }
            total += values.fileSize ?? 0
        }
        return total
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
