import Foundation

/// Scratch files that briefly hold clipboard or screenshot content (Quick Look previews, drag-out images).
///
/// They live in one folder that Edison empties on launch and when each preview or editor closes, so content
/// deleted from history never lingers on disk.
enum TemporaryFiles {
    enum Area: String {
        case quickLook = "QuickLook"
        case dragOut = "DragOut"
    }

    static let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("Edison", isDirectory: true)

    /// A file URL inside `area`, with its folder created and readable only by the current user.
    static func url(in area: Area, subfolder: String? = nil, fileName: String) throws -> URL {
        var directory = rootDirectory.appendingPathComponent(area.rawValue, isDirectory: true)
        if let subfolder {
            directory.appendPathComponent(subfolder, isDirectory: true)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return directory.appendingPathComponent(fileName)
    }

    static func purge(_ area: Area) {
        try? FileManager.default.removeItem(at: rootDirectory.appendingPathComponent(area.rawValue, isDirectory: true))
    }

    static func purgeAll() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }
}
