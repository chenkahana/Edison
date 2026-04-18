import Foundation
import OSLog

final class ShortcutStore {
    private let defaults: UserDefaults
    private let key = "edison.shortcuts.v2"
    private let legacyKey = "edison.shortcuts.v1"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: ShortcutSet {
        if let data = defaults.data(forKey: key) {
            do {
                return try decoder.decode(ShortcutSet.self, from: data)
            } catch {
                Log.shortcuts.error("ShortcutStore: decode failed – \(error.localizedDescription)")
                return .default
            }
        }

        if let migrated = migrateLegacyShortcuts() {
            save(migrated)
            defaults.removeObject(forKey: legacyKey)
            return migrated
        }

        return .default
    }

    func save(_ shortcuts: ShortcutSet) {
        do {
            let data = try encoder.encode(shortcuts)
            defaults.set(data, forKey: key)
        } catch {
            Log.shortcuts.error("ShortcutStore: save failed – \(error.localizedDescription)")
        }
    }

    private func migrateLegacyShortcuts() -> ShortcutSet? {
        guard let data = defaults.data(forKey: legacyKey) else {
            return nil
        }

        guard let legacy = try? decoder.decode(LegacyShortcutSet.self, from: data) else {
            return nil
        }

        var map: [ShortcutAction: Shortcut] = [:]
        if let shortcut = legacy.map[.openHub] {
            map[.openHub] = shortcut
        }
        if let shortcut = legacy.map[.captureArea] {
            map[.captureScreenshot] = shortcut
        }
        if let shortcut = legacy.map[.captureWindow] {
            map[.captureWindow] = shortcut
        }
        if let shortcut = legacy.map[.captureFullScreen] {
            map[.captureFullScreen] = shortcut
        }

        for action in ShortcutAction.allCases where map[action] == nil {
            if let shortcut = ShortcutSet.default[action] {
                map[action] = shortcut
            }
        }

        return ShortcutSet(map: map)
    }
}

private enum LegacyShortcutAction: String, Codable, Hashable {
    case openHub
    case captureArea
    case captureWindow
    case captureFullScreen
}

private struct LegacyShortcutSet: Codable, Hashable {
    var map: [LegacyShortcutAction: Shortcut]
}
