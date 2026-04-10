import Foundation

enum ClipboardPayload: Codable, Hashable {
    case text(String)
    case image(Data)
    case fileURL(URL)
}

struct ClipboardItem: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    var isFavorite: Bool
    let payload: ClipboardPayload

    init(id: UUID = UUID(), createdAt: Date = .now, isFavorite: Bool = false, payload: ClipboardPayload) {
        self.id = id
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.payload = payload
    }
}
