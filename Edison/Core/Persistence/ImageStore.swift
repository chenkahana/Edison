import Foundation
import OSLog

/// Manages on-disk storage for clipboard image and thumbnail files.
/// Images are stored in `{AppSupport}/Edison/images/` as PNG files.
/// `ClipboardImageData` holds only relative filenames; blobs never go into history.json.
enum ImageStore {
    static let imagesDirectoryURL: URL = {
        let dir = HistoryStore.storageDirectory.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Writes image data to disk and returns the relative filename.
    static func save(imageData: Data, id: UUID) throws -> String {
        let filename = "\(id.uuidString).png"
        let url = imagesDirectoryURL.appendingPathComponent(filename)
        try imageData.write(to: url, options: .atomic)
        return filename
    }

    /// Writes thumbnail data to disk and returns the relative filename.
    static func saveThumbnail(data: Data, id: UUID) throws -> String {
        let filename = "\(id.uuidString)-thumb.png"
        let url = imagesDirectoryURL.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return filename
    }

    /// Loads image data from the given relative path.
    static func load(relativePath: String) throws -> Data {
        let url = imagesDirectoryURL.appendingPathComponent(relativePath)
        return try Data(contentsOf: url)
    }

    /// Silently deletes the file for a relative path. Safe to call with stale paths.
    static func delete(relativePath: String) {
        let url = imagesDirectoryURL.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }

    /// Called during Codable migration: persists inline Data blobs to disk and returns the new paths.
    static func migrate(imageData: Data, thumbnailData: Data) throws -> (imagePath: String, thumbnailPath: String) {
        let id = UUID()
        let imagePath = try save(imageData: imageData, id: id)
        let thumbnailPath = try saveThumbnail(data: thumbnailData, id: id)
        return (imagePath, thumbnailPath)
    }
}
