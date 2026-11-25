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
    /// The text-model pass that last ran on this item, whether or not it produced anything
    /// (unsupported language, refusal); nil until it has run.
    var textModelPass: Int?

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
}
