import AppKit
import Carbon
import Foundation

enum ShortcutValidationIssue: Equatable {
    case duplicate(with: ShortcutAction)
    case reservedShortcut
    case missingModifiers

    var message: String {
        switch self {
        case let .duplicate(with):
            return "Conflicts with \(with.title)."
        case .reservedShortcut:
            return "This shortcut is reserved by Edison or macOS."
        case .missingModifiers:
            return "Use at least one modifier key."
        }
    }
}

enum ShortcutValidator {
    static func validationIssues(for shortcuts: ShortcutSet) -> [ShortcutAction: [ShortcutValidationIssue]] {
        var result: [ShortcutAction: [ShortcutValidationIssue]] = [:]
        let duplicates = Dictionary(grouping: shortcuts.map) { $0.value }
            .filter { $0.value.count > 1 }

        for action in ShortcutAction.allCases {
            guard let shortcut = shortcuts[action] else { continue }

            var issues: [ShortcutValidationIssue] = []
            if shortcut.modifiers == 0 {
                issues.append(.missingModifiers)
            }
            if isReserved(shortcut) {
                issues.append(.reservedShortcut)
            }
            if let duplicate = duplicates[shortcut]?.map(\.key).first(where: { $0 != action }) {
                issues.append(.duplicate(with: duplicate))
            }
            if !issues.isEmpty {
                result[action] = issues
            }
        }

        return result
    }

    private static func isReserved(_ shortcut: Shortcut) -> Bool {
        let keyCode = shortcut.keyCode
        let modifiers = shortcut.modifiers

        if modifiers == UInt32(cmdKey), keyCode == UInt32(kVK_ANSI_Q) {
            return true
        }
        if modifiers == UInt32(cmdKey), keyCode == UInt32(kVK_ANSI_W) {
            return true
        }
        if modifiers == UInt32(cmdKey), keyCode == UInt32(kVK_ANSI_Comma) {
            return true
        }

        return false
    }
}
