import AppKit
import Carbon
import Foundation

enum ShortcutAction: String, CaseIterable, Codable, Hashable, Identifiable {
    case openHub
    case captureScreenshot
    case captureWindow
    case captureFullScreen
    case capturePreviousArea
    case editLastScreenshot
    case toggleHistoryPause
    case openSettings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openHub: return "Open Hub"
        case .captureScreenshot: return "Capture Area"
        case .captureWindow: return "Capture Window"
        case .captureFullScreen: return "Capture Full Screen"
        case .capturePreviousArea: return "Capture Previous Area"
        case .editLastScreenshot: return "Annotate Last Screenshot"
        case .toggleHistoryPause: return "Pause or Resume Clipboard History"
        case .openSettings: return "Open Settings"
        }
    }
}

struct Shortcut: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    // ⌃⌥⌘ combinations aren't used by macOS or by the standard app menus, so registering them globally doesn't
    // take a command away from other apps. ⇧⌘V (Paste and Match Style) and ⇧⌘S (Save As/Duplicate) did.
    static let defaultOpenHub = Shortcut(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | optionKey | controlKey)
    )

    static let defaultCaptureScreenshot = Shortcut(
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(cmdKey | optionKey | controlKey)
    )

    /// The defaults before 2.2, kept for people who already use Edison.
    static let previousDefaultOpenHub = Shortcut(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    static let previousDefaultCaptureScreenshot = Shortcut(
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    static func commandShift(_ keyCode: Int) -> Shortcut {
        Shortcut(keyCode: UInt32(keyCode), modifiers: UInt32(cmdKey | shiftKey))
    }
}

extension Shortcut {
    /// The modifier flags a menu item shows for this shortcut.
    var menuModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    /// The shortcut as Mac menus write it, for example ⌃⌥⌘V.
    var displayString: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + (menuKeyEquivalent?.uppercased() ?? "?")
    }

    /// The character a menu item shows for this shortcut's key in the current keyboard layout, or nil when the
    /// layout gives none.
    var menuKeyEquivalent: String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }

        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(1 << kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &length,
            &characters
        )
        let key = String(utf16CodeUnits: characters, count: length).lowercased()
        guard status == noErr, !key.isEmpty,
              key.rangeOfCharacter(from: .controlCharacters.union(.whitespaces)) == nil else {
            return nil
        }
        return key
    }
}

struct ShortcutSet: Codable, Hashable {
    var map: [ShortcutAction: Shortcut]

    static let `default` = ShortcutSet(map: [
        .openHub: .defaultOpenHub,
        .captureScreenshot: .defaultCaptureScreenshot
    ])

    static let previousDefault = ShortcutSet(map: [
        .openHub: .previousDefaultOpenHub,
        .captureScreenshot: .previousDefaultCaptureScreenshot
    ])

    static func defaultShortcut(for action: ShortcutAction) -> Shortcut? {
        switch action {
        case .openHub:
            return .defaultOpenHub
        case .captureScreenshot:
            return .defaultCaptureScreenshot
        case .captureWindow, .captureFullScreen, .capturePreviousArea, .editLastScreenshot, .toggleHistoryPause, .openSettings:
            return nil
        }
    }

    subscript(action: ShortcutAction) -> Shortcut? {
        get { map[action] }
        set { map[action] = newValue }
    }
}
