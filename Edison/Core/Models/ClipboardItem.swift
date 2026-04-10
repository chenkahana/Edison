import Foundation

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
