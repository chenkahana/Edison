import Foundation

/// What Edison works out about an item on this Mac, after capture. It is metadata only: nothing
/// here changes the stored payload or what pastes. Every field is optional so history saved
/// before a field existed (or by an older build) still decodes.
struct ClipboardIntelligence: Codable, Hashable {
    /// Text, code or terminal, from the on-device language model. Used only where the
    /// deterministic classifier isn't sure (`ClipboardContentClassifier.classify`).
    var modelKind: ClipboardContentKind?
    /// One to three short, lowercase topic tags.
    var topics: [String]?
    /// The text-model pass that last ran on this item (on its text, or an image's recognised
    /// text), whether or not it produced anything (unsupported language, refusal); nil until it has run.
    var textModelPass: Int?

    /// Text recognised in an image by Vision, capped at a few thousand characters.
    var recognizedText: String?
    /// Vision's scene labels for an image ("document", "screenshot", "outdoor"…).
    var imageLabels: [String]?
    /// The payload of the first barcode or QR code found in an image.
    var barcodePayload: String?
    /// A one-line description from the on-device model's image input (macOS 27+).
    var caption: String?
    /// An older image this one looks almost exactly like (by Vision feature print).
    var nearDuplicateOf: UUID?
    /// The Vision pass that last ran on this image; nil until it has run.
    var visionPass: Int?
    /// The image-model pass that last ran on this image; nil until it has run.
    var imageModelPass: Int?
    /// The search-vector pass that last ran on this item; reset whenever tags, captions or
    /// recognised text change, so the vector is rebuilt from them.
    var searchVectorPass: Int?

    static func resolvedKind(
        classified: ClipboardContentKind,
        isConfident: Bool,
        modelKind: ClipboardContentKind?
    ) -> ClipboardContentKind {
        guard !isConfident,
              let modelKind,
              [.text, .code, .terminal].contains(classified),
              [.text, .code, .terminal].contains(modelKind) else {
            return classified
        }
        return modelKind
    }

    /// Lowercased, trimmed, deduplicated and capped, so a chatty model can't flood cards or search.
    static func normalizedTopics(_ topics: [String]) -> [String] {
        var seen = Set<String>()
        return topics
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased() }
            .filter { !$0.isEmpty && $0.count <= 24 && seen.insert($0).inserted }
            .prefix(3)
            .map { $0 }
    }
}

extension ClipboardItem {
    var topics: [String] { intelligence?.topics ?? [] }

    /// A web link read from a QR code or barcode in an image, to open from the card.
    var barcodeURL: URL? {
        guard case .image = payload,
              let payload = intelligence?.barcodePayload else { return nil }
        return ClipboardContentClassifier.link(in: payload.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Words that describe an image for search and VoiceOver: caption, recognised text, labels and
    /// barcode content. Empty for other items.
    var imageSearchText: [String] {
        guard case .image = payload, let intelligence else { return [] }
        return [intelligence.caption, intelligence.recognizedText, intelligence.barcodePayload].compactMap { $0 }
            + (intelligence.imageLabels ?? [])
    }
}
