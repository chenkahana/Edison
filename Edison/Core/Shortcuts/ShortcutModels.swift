import AppKit
import Carbon
import Foundation

enum ShortcutAction: String, CaseIterable, Codable, Hashable, Identifiable {
    case openHub
    case captureArea
    case captureWindow
    case captureFullScreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openHub: return "Open Edison"
        case .captureArea: return "Capture Area"
        case .captureWindow: return "Capture Window"
        case .captureFullScreen: return "Capture Full Screen"
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

    static func commandShift(_ keyCode: Int) -> Shortcut {
        Shortcut(keyCode: UInt32(keyCode), modifiers: UInt32(cmdKey | shiftKey))
    }
}

struct ShortcutSet: Codable, Hashable {
    var map: [ShortcutAction: Shortcut]

    static let `default` = ShortcutSet(map: [
        .openHub: .defaultOpenHub,
        .captureArea: .commandShift(kVK_ANSI_2),
        .captureWindow: .commandShift(kVK_ANSI_3),
        .captureFullScreen: .commandShift(kVK_ANSI_4)
    ])

    subscript(action: ShortcutAction) -> Shortcut {
        get { map[action] ?? Shortcut.defaultOpenHub }
        set { map[action] = newValue }
    }
}
