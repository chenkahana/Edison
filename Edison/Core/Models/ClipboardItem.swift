import Foundation
import OSLog

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

struct ClipboardRepresentationDescriptor: Codable, Hashable {
    let typeIdentifier: String
    let relativePath: String
    let byteCount: Int
    let sha256: String
}

enum ClipboardRepresentationDegradationReason: String, Codable, Hashable {
    case readFailure
    case representationSizeLimit
    case itemSizeLimit
    case storeSizeLimit
    case persistenceFailure
}

struct ClipboardRepresentationDegradation: Codable, Hashable {
    let typeIdentifier: String
    let reason: ClipboardRepresentationDegradationReason
    let sha256: String?

    init(
        typeIdentifier: String,
        reason: ClipboardRepresentationDegradationReason,
        sha256: String? = nil
    ) {
        self.typeIdentifier = typeIdentifier
        self.reason = reason
        self.sha256 = sha256
    }
}

struct ClipboardTextRepresentations: Codable, Hashable {
    let declaredTypeIdentifiers: [String]
    let storedRepresentations: [ClipboardRepresentationDescriptor]
    let degradations: [ClipboardRepresentationDegradation]
}

struct ClipboardItem: Codable, Identifiable, Hashable {
    let id: UUID
    var createdAt: Date
    var isFavorite: Bool
    let sourceApplication: ClipboardSourceApplication?
    let payload: ClipboardPayload
    let textRepresentations: ClipboardTextRepresentations?
    /// Labels and tags derived on this Mac; never part of what pastes. Nil until processed.
    var intelligence: ClipboardIntelligence?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        isFavorite: Bool = false,
        sourceApplication: ClipboardSourceApplication? = nil,
        payload: ClipboardPayload,
        textRepresentations: ClipboardTextRepresentations? = nil,
        intelligence: ClipboardIntelligence? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.sourceApplication = sourceApplication
        self.payload = payload
        self.textRepresentations = textRepresentations
        self.intelligence = intelligence
    }
}

extension ClipboardItem {
    /// Number of Unicode scalars in a text payload; nil for non-text payloads.
    var characterCount: Int? {
        guard case let .text(text) = payload else { return nil }
        return text.unicodeScalars.count
    }

    func hasSameClipboardIdentity(as other: ClipboardItem) -> Bool {
        switch (payload, other.payload) {
        case let (.text(text), .text(otherText)):
            return Data(text.utf8) == Data(otherText.utf8)
                && richRepresentationIdentity == other.richRepresentationIdentity
        default:
            return payload == other.payload
        }
    }

    private var richRepresentationIdentity: [ClipboardRichRepresentationIdentity] {
        guard case .text = payload,
              let textRepresentations else { return [] }

        let descriptorsByType = Dictionary(
            textRepresentations.storedRepresentations.map { ($0.typeIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let degradationDigestsByType = Dictionary(
            textRepresentations.degradations.compactMap { degradation -> (String, String)? in
                guard let sha256 = degradation.sha256 else { return nil }
                return (degradation.typeIdentifier, sha256)
            },
            uniquingKeysWith: { first, _ in first }
        )
        return textRepresentations.declaredTypeIdentifiers.compactMap { typeIdentifier in
            guard typeIdentifier != "public.utf8-plain-text" else { return nil }
            let sha256 = descriptorsByType[typeIdentifier]?.sha256
                ?? degradationDigestsByType[typeIdentifier]
            guard let sha256 else { return nil }
            return ClipboardRichRepresentationIdentity(
                typeIdentifier: typeIdentifier,
                sha256: sha256
            )
        }
    }
}

private struct ClipboardRichRepresentationIdentity: Hashable {
    let typeIdentifier: String
    let sha256: String
}
