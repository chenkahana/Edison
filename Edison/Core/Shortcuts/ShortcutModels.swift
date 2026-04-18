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
    case openSettings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openHub: return "Open Edison"
        case .captureScreenshot: return "Capture Screenshot"
        case .captureWindow: return "Capture Window"
        case .captureFullScreen: return "Capture Full Screen"
        case .capturePreviousArea: return "Capture Previous Area"
        case .editLastScreenshot: return "Edit Last Screenshot"
        case .openSettings: return "Open Settings"
        }
    }
}

struct Shortcut: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultOpenHub = Shortcut(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    static let defaultCaptureScreenshot = Shortcut(
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    static func commandShift(_ keyCode: Int) -> Shortcut {
        Shortcut(keyCode: UInt32(keyCode), modifiers: UInt32(cmdKey | shiftKey))
    }
}

struct ShortcutSet: Codable, Hashable {
    var map: [ShortcutAction: Shortcut]

    static let `default` = ShortcutSet(map: [
        .openHub: .defaultOpenHub,
        .captureScreenshot: .defaultCaptureScreenshot
    ])

    static func defaultShortcut(for action: ShortcutAction) -> Shortcut? {
        switch action {
        case .openHub:
            return .defaultOpenHub
        case .captureScreenshot:
            return .defaultCaptureScreenshot
        case .captureWindow, .captureFullScreen, .capturePreviousArea, .editLastScreenshot, .openSettings:
            return nil
        }
    }

    subscript(action: ShortcutAction) -> Shortcut? {
        get { map[action] }
        set { map[action] = newValue }
    }
}
