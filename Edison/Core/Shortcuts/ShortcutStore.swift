import Foundation
import OSLog

final class ShortcutStore {
    private let key = "edison.shortcuts.v1"

    var current: ShortcutSet {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let shortcuts = try? JSONDecoder().decode(ShortcutSet.self, from: data)
        else {
            return .default
        }
        return shortcuts
    }

    func save(_ shortcuts: ShortcutSet) {
        do {
            let data = try JSONEncoder().encode(shortcuts)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            Log.shortcuts.error("ShortcutStore: save failed – \(error.localizedDescription)")
        }
    }
}
