import Carbon
import AppKit
import SwiftUI

struct ShortcutEditorRow: View {
    let action: ShortcutAction
    @Binding var shortcut: Shortcut

    var body: some View {
        HStack {
            Text(action.title)
                .foregroundStyle(.primary)
            Spacer()
            KeyRecorderView(shortcut: $shortcut)
                .frame(width: 200, height: 28)
        }
    }
}

// MARK: - Key Recorder

private struct KeyRecorderView: NSViewRepresentable {
    @Binding var shortcut: Shortcut

    func makeCoordinator() -> Coordinator { Coordinator(shortcut: $shortcut) }

    func makeNSView(context: Context) -> KeyRecorderField {
        let field = KeyRecorderField()
        field.coordinator = context.coordinator
        context.coordinator.field = field
        return field
    }

    func updateNSView(_ field: KeyRecorderField, context: Context) {
        field.displayShortcut = shortcut
        field.needsDisplay = true
    }

    final class Coordinator: NSObject {
        var shortcutBinding: Binding<Shortcut>
        weak var field: KeyRecorderField?

        init(shortcut: Binding<Shortcut>) {
            self.shortcutBinding = shortcut
        }

        func commit(_ shortcut: Shortcut) {
            shortcutBinding.wrappedValue = shortcut
        }
    }
}

final class KeyRecorderField: NSView {
    fileprivate weak var coordinator: KeyRecorderView.Coordinator?
    var displayShortcut: Shortcut = Shortcut(keyCode: 0, modifiers: 0)
    private var isRecording = false
    private var monitor: Any?

    override var acceptsFirstResponder: Bool { true }

    deinit {
        removeMonitor()
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg: NSColor = isRecording
            ? NSColor.selectedControlColor.withAlphaComponent(0.18)
            : NSColor.controlBackgroundColor.withAlphaComponent(0.60)
        bg.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 7, yRadius: 7).fill()

        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7)
        border.lineWidth = 1
        border.stroke()

        let label: String = isRecording ? "Type shortcut\u{2026}" : shortcutDescription(displayShortcut)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let size = str.size()
        str.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        needsDisplay = true
        installMonitor()
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        removeMonitor()
        return true
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            if event.keyCode == 53 { // Escape
                self.window?.makeFirstResponder(nil)
                return nil
            }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !mods.isEmpty else { return nil }
            let shortcut = Shortcut(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers(from: mods))
            self.coordinator?.commit(shortcut)
            self.displayShortcut = shortcut
            self.needsDisplay = true
            self.window?.makeFirstResponder(nil)
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func shortcutDescription(_ s: Shortcut) -> String {
        var parts: [String] = []
        if s.modifiers & UInt32(controlKey) != 0 { parts.append("\u{2303}") }
        if s.modifiers & UInt32(optionKey) != 0 { parts.append("\u{2325}") }
        if s.modifiers & UInt32(shiftKey) != 0 { parts.append("\u{21E7}") }
        if s.modifiers & UInt32(cmdKey) != 0 { parts.append("\u{2318}") }
        parts.append(keyName(for: UInt16(s.keyCode)))
        return parts.joined()
    }

    private func keyName(for keyCode: UInt16) -> String {
        let special: [UInt16: String] = [
            36: "\u{21A9}", 48: "\u{21E5}", 49: "Space", 51: "\u{232B}", 53: "\u{238B}",
            123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
            115: "Home", 119: "End", 116: "PgUp", 121: "PgDn",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 109: "F10", 111: "F12",
            122: "F1", 120: "F2", 118: "F4"
        ]
        if let name = special[keyCode] { return name }

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        guard let kb = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(kb, kTISPropertyUnicodeKeyLayoutData) else {
            return "?"
        }
        let layout = unsafeBitCast(layoutData, to: CFData.self)
        let layoutPtr = unsafeBitCast(CFDataGetBytePtr(layout), to: UnsafePointer<UCKeyboardLayout>.self)
        UCKeyTranslate(layoutPtr, keyCode, UInt16(kUCKeyActionDisplay), 0,
                       UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                       &deadKeyState, 4, &length, &chars)
        let result = String(utf16CodeUnits: chars, count: length).uppercased()
        return result.isEmpty ? "?" : result
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }
}
