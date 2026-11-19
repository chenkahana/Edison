import ApplicationServices
import Combine
import SwiftUI

/// The one window a new install sees: how to open the Hub and capture, and the two permissions with live status.
struct FirstRunView: View {
    @EnvironmentObject private var appState: AppState
    let onDone: () -> Void

    @State private var screenRecordingGranted = CGPreflightScreenCaptureAccess()
    @State private var accessibilityGranted = AXIsProcessTrusted()
    private let statusTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x4) {
            Text("Welcome to Edison")
                .font(.title2.weight(.semibold))
            Text("Edison lives in the menu bar and keeps what you copy and capture on this Mac.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
                shortcutRow(.openHub, "opens the Hub with your history.")
                shortcutRow(.captureScreenshot, "captures an area of the screen.")
                Text("Click the menu-bar icon to open the Hub; right-click it for everything else.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            permissionRow(
                title: "Screen Recording",
                detail: "Needed to capture screenshots. macOS may ask you to quit and reopen Edison after you allow it.",
                isGranted: screenRecordingGranted,
                action: appState.requestScreenRecordingAccess
            )
            permissionRow(
                title: "Accessibility",
                detail: "Lets Edison paste for you. Without it, items are copied and you press ⌘V.",
                isGranted: accessibilityGranted,
                action: appState.requestAccessibilityAccess
            )

            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(HubTheme.Space.x5)
        .frame(width: 460)
        .onReceive(statusTimer) { _ in
            screenRecordingGranted = CGPreflightScreenCaptureAccess()
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    private func shortcutRow(_ action: ShortcutAction, _ text: String) -> some View {
        let keys = appState.shortcutStore.current[action]?.displayString ?? "Its shortcut"
        return Text("**\(keys)** \(text)")
    }

    private func permissionRow(title: String, detail: String, isGranted: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: HubTheme.Space.x3) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isGranted ? .green : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: HubTheme.Space.x1) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if isGranted {
                Text("Allowed").foregroundStyle(.secondary)
            } else {
                Button("Allow…", action: action)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isGranted ? "Allowed" : "Not allowed")
    }
}
