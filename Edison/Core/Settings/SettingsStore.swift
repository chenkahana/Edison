import Foundation
import OSLog

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "edison.settings.v1"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: AppSettings {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }

        do {
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            Log.settings.error("SettingsStore: decode failed – \(error.localizedDescription)")
            return .default
        }
    }

    func save(_ settings: AppSettings) {
        do {
            let data = try encoder.encode(settings)
            defaults.set(data, forKey: key)
        } catch {
            Log.settings.error("SettingsStore: save failed – \(error.localizedDescription)")
        }
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}
