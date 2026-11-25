import Foundation

enum CaptureDefaultResult: String, Codable, CaseIterable, Hashable, Identifiable {
    case copyAndOpenEditor
    case openEditorOnly
    case saveAndOpenEditor
    case keepInHistory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copyAndOpenEditor:
            return "Copy to Clipboard"
        case .openEditorOnly, .saveAndOpenEditor, .keepInHistory:
            return "Don't Copy"
        }
    }
}

struct AnnotationStyleSettings: Codable, Hashable {
    var color: CodableColor
    var lineWidth: Double
    var fontSize: Double
    var blurRadius: Double

    static let `default` = AnnotationStyleSettings(
        color: .systemRed,
        lineWidth: 6,
        fontSize: 34,
        blurRadius: 18
    )
}

struct GeneralSettings: Codable, Hashable {
    var launchAtLogin = false
}

struct CaptureSettings: Codable, Hashable {
    var openEditorAfterCapture = false
    var rememberLastArea = true
    var showMagnifierAndDimensions = true
    var defaultResult: CaptureDefaultResult = .copyAndOpenEditor
    var defaultSaveFolderPath: String?
    var filenameTemplate = "Edison Screenshot {date} {time}"
}

struct EditorSettings: Codable, Hashable {
    var closeAfterCopySave = false
    var rememberWindowSize = true
    var defaultStyle = AnnotationStyleSettings.default
}

struct PrivacySettings: Codable, Hashable {
    var historyLimit = 250
    /// Drops non-favorite items older than this many days. `nil` keeps history forever (until the
    /// count limit trims it). Missing from settings saved before this existed, which decodes as `nil`.
    var retentionDays: Int?
}

struct IntelligenceSettings: Codable, Hashable {
    /// Labels, tags and (on newer macOS) captions worked out on this Mac. On by default.
    var isEnabled = true
}

struct AppSettings: Codable, Hashable {
    static let currentSchemaVersion = 1

    var schemaVersion = AppSettings.currentSchemaVersion
    var general = GeneralSettings()
    var capture = CaptureSettings()
    var editor = EditorSettings()
    var privacy = PrivacySettings()
    var intelligence = IntelligenceSettings()

    static let `default` = AppSettings()

    func defaultFileName(at date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = .current
        timeFormatter.dateFormat = "HH.mm.ss"

        let raw = capture.filenameTemplate
            .replacingOccurrences(of: "{date}", with: formatter.string(from: date))
            .replacingOccurrences(of: "{time}", with: timeFormatter.string(from: date))

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Edison Screenshot \(formatter.string(from: date)) \(timeFormatter.string(from: date))" : trimmed
    }
}

extension AppSettings {
    /// Settings saved before a section existed lack its key; that section takes its defaults
    /// instead of the whole decode failing and every setting resetting.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? defaults.schemaVersion
        general = try container.decodeIfPresent(GeneralSettings.self, forKey: .general) ?? defaults.general
        capture = try container.decodeIfPresent(CaptureSettings.self, forKey: .capture) ?? defaults.capture
        editor = try container.decodeIfPresent(EditorSettings.self, forKey: .editor) ?? defaults.editor
        privacy = try container.decodeIfPresent(PrivacySettings.self, forKey: .privacy) ?? defaults.privacy
        intelligence = try container.decodeIfPresent(IntelligenceSettings.self, forKey: .intelligence)
            ?? defaults.intelligence
    }
}
