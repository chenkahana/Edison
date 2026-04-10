import Foundation

struct ItemCollection: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var accentHex: String?
    var itemIDs: [UUID]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, accentHex: String? = nil, itemIDs: [UUID] = [], createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.accentHex = accentHex
        self.itemIDs = itemIDs
        self.createdAt = createdAt
    }
}
