import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardImageData: Codable, Hashable {
    let data: Data
    let thumbnailData: Data
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
            return imageData.data
        } importing: { data in
            let imgData = ClipboardImageData(data: data, thumbnailData: data)
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
