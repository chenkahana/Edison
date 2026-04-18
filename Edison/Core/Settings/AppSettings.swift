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
            return "Copy + Open Editor"
        case .openEditorOnly:
            return "Open Editor Only"
        case .saveAndOpenEditor:
            return "Save + Open Editor"
        case .keepInHistory:
            return "Keep In History"
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
    var startHiddenWhenLaunchedAtLogin = true
}

struct CaptureSettings: Codable, Hashable {
    var openEditorAfterCapture = true
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
}

struct AppSettings: Codable, Hashable {
    static let currentSchemaVersion = 1

    var schemaVersion = AppSettings.currentSchemaVersion
    var general = GeneralSettings()
    var capture = CaptureSettings()
    var editor = EditorSettings()
    var privacy = PrivacySettings()

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
