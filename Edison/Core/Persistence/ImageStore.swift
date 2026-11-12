import Foundation
import ImageIO
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

    private static let pixelSizeCache = NSCache<NSString, NSValue>()

    /// Pixel dimensions read from the image header only (no full decode), cached per path.
    static func pixelSize(relativePath: String) -> CGSize? {
        let key = relativePath as NSString
        if let cached = pixelSizeCache.object(forKey: key) {
            return cached.sizeValue
        }
        let url = imagesDirectoryURL.appendingPathComponent(relativePath)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        let size = CGSize(width: width, height: height)
        pixelSizeCache.setObject(NSValue(size: size), forKey: key)
        return size
    }

    /// Silently deletes the file for a relative path. Safe to call with stale paths.
    static func delete(relativePath: String) {
        let url = imagesDirectoryURL.appendingPathComponent(relativePath)
        pixelSizeCache.removeObject(forKey: relativePath as NSString)
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
