import AppKit
import SwiftUI

/// A floating, non-activating banner for alerts and capture feedback that must stay visible even when
/// the Hub is closed, and must not block the run loop or hide behind the frontmost app the way
/// `NSAlert.runModal()` can when triggered from a hotkey.
@MainActor
final class MessageHUD {
    private static let margin: CGFloat = 24
    private static let lifetime: TimeInterval = 8

    private var panel: NSPanel?
    private var dismissTimer: Timer?

    func show(message: String, actions: [HubMessageBanner.Action] = [], on screen: NSScreen? = nil) {
        close()
        guard let screen = screen ?? Self.screenUnderPointer() ?? NSScreen.main else { return }

        let hosting = NSHostingView(
            rootView: HubMessageBanner(message: message, actions: actions, dismiss: { [weak self] in self?.close() })
        )
        let fittingSize = hosting.fittingSize
        let frame = NSRect(
            x: screen.visibleFrame.midX - fittingSize.width / 2,
            y: screen.visibleFrame.maxY - fittingSize.height - Self.margin,
            width: fittingSize.width,
            height: fittingSize.height
        )
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = hosting
        panel.orderFrontRegardless()
        self.panel = panel
        scheduleDismiss()
    }

    func close() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func scheduleDismiss() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: Self.lifetime, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private static func screenUnderPointer() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) }
    }
}
