import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardImageData: Hashable {
    let imagePath: String
    let thumbnailPath: String

    init(imagePath: String, thumbnailPath: String) {
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
    }
}

// MARK: - Codable with legacy migration

extension ClipboardImageData: Codable {
    private enum CodingKeys: String, CodingKey {
        // Current format
        case imagePath, thumbnailPath
        // Legacy format (inline Data blobs — pre-1.1)
        case data, thumbnailData
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try current path-based format first
        if let path = try? container.decode(String.self, forKey: .imagePath),
           let thumbPath = try? container.decode(String.self, forKey: .thumbnailPath) {
            self.imagePath = path
            self.thumbnailPath = thumbPath
            return
        }

        // Legacy format: inline Data blobs — migrate to disk transparently
        let imageData = try container.decode(Data.self, forKey: .data)
        let thumbnailData = try container.decode(Data.self, forKey: .thumbnailData)
        do {
            let paths = try ImageStore.migrate(imageData: imageData, thumbnailData: thumbnailData)
            self.imagePath = paths.imagePath
            self.thumbnailPath = paths.thumbnailPath
        } catch {
            Log.store.error("ClipboardImageData: legacy migration failed – \(error.localizedDescription)")
            throw error
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(imagePath, forKey: .imagePath)
        try container.encode(thumbnailPath, forKey: .thumbnailPath)
    }
}

struct ClipboardSourceApplication: Codable, Hashable {
    let bundleIdentifier: String
    let localizedName: String?
}

enum ClipboardPayload: Codable, Hashable {
    case text(String)
    case image(ClipboardImageData)
    case fileURL(URL)
}

struct ClipboardItem: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    var isFavorite: Bool
    let sourceApplication: ClipboardSourceApplication?
    let payload: ClipboardPayload

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        isFavorite: Bool = false,
        sourceApplication: ClipboardSourceApplication? = nil,
        payload: ClipboardPayload
    ) {
        self.id = id
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.sourceApplication = sourceApplication
        self.payload = payload
    }
}

extension ClipboardItem {
    /// Number of Unicode scalars in a text payload; nil for non-text payloads.
    var characterCount: Int? {
        guard case let .text(text) = payload else { return nil }
        return text.unicodeScalars.count
    }
}

extension ClipboardItem: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .utf8PlainText) { item in
            switch item.payload {
            case let .text(text):
                return text.data(using: .utf8) ?? Data()
            case let .fileURL(url):
                return url.path.data(using: .utf8) ?? Data()
            case .image:
                return Data()
            }
        } importing: { data in
            let text = String(data: data, encoding: .utf8) ?? ""
            return ClipboardItem(payload: .text(text))
        }

        DataRepresentation(contentType: .png) { item in
            guard case let .image(imageData) = item.payload else { return Data() }
            return (try? ImageStore.load(relativePath: imageData.imagePath)) ?? Data()
        } importing: { data in
            let id = UUID()
            let imgData = ClipboardImageData(
                imagePath: try ImageStore.save(imageData: data, id: id),
                thumbnailPath: try ImageStore.saveThumbnail(data: data, id: id)
            )
            return ClipboardItem(payload: .image(imgData))
        }

        FileRepresentation(contentType: .fileURL) { item in
            guard case let .fileURL(url) = item.payload else {
                throw CocoaError(.fileNoSuchFile)
            }
            return SentTransferredFile(url)
        } importing: { received in
            ClipboardItem(payload: .fileURL(received.file))
        }
    }
}
