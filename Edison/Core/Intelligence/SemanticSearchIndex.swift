import Foundation
import NaturalLanguage

/// Search by meaning: each item gets a vector (the mean of NaturalLanguage's on-device word
/// vectors over its topic tags, caption, image labels and text), and a query matches items whose
/// vector points the same way.
///
/// Word vectors, not `NLEmbedding.sentenceEmbedding`: on Edison's query set, sentence vectors put
/// the right item first for 6–9 of 15 queries, and mean-pooled `NLContextualEmbedding` couldn't
/// separate anything; word vectors weighted toward the topic tags got 14 of 15.
final class SemanticSearchIndex: @unchecked Sendable {
    static let shared = SemanticSearchIndex()

    /// A related item must reach this cosine similarity and stand this far above the background
    /// (the sixth-best score): word vectors put every item somewhat near every query, so only items
    /// that stand out count. Calibrated on Edison's fixture set, where unrelated queries ("giraffe",
    /// "wedding dress", "guitar lessons") return nothing.
    static let minimumSimilarity: Float = 0.55
    static let minimumLeadOverBackground: Float = 0.1
    static let backgroundRank = 5
    static let fallbackBackground: Float = 0.45
    static let maximumResults = 8

    private let lock = NSLock()
    private var vectors: [UUID: [Float]] = [:]

    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "you", "your", "are", "was", "but", "not",
        "have", "has", "had", "its", "our", "out", "all", "can", "will", "into", "onto", "about", "then"
    ]

    /// Nil when the text has no words the English word vectors know.
    static func vector(for text: String) -> [Float]? {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else { return nil }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var sum = [Double](repeating: 0, count: embedding.dimension)
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = text[range].lowercased()
            guard word.count >= 3, !stopWords.contains(word),
                  let vector = embedding.vector(for: word) else { return true }
            for index in vector.indices { sum[index] += vector[index] }
            count += 1
            return count < 400
        }
        guard count > 0 else { return nil }
        let norm = sum.reduce(0) { $0 + $1 * $1 }.squareRoot()
        guard norm > 0 else { return nil }
        return sum.map { Float($0 / norm) }
    }

    /// What an item's vector is built from. Tags and captions are repeated: they say what the item
    /// is about in a few words, where the text's own words are diluted by everything else in it.
    static func document(for item: ClipboardItem) -> String? {
        let intelligence = item.intelligence
        let summary = item.topics + [intelligence?.caption].compactMap { $0 }
        var parts = summary + summary + (intelligence?.imageLabels ?? [])
        switch item.payload {
        case let .text(text): parts.append(String(text.prefix(1_000)))
        case .image: parts.append(String((intelligence?.recognizedText ?? "").prefix(1_000)))
        case let .fileURL(url): parts.append(url.deletingPathExtension().lastPathComponent)
        }
        let document = parts.joined(separator: ". ").trimmingCharacters(in: .whitespacesAndNewlines)
        return document.isEmpty ? nil : document
    }

    func set(_ vector: [Float]?, for itemID: UUID) {
        lock.withLock { vectors[itemID] = vector }
    }

    func contains(_ itemID: UUID) -> Bool {
        lock.withLock { vectors[itemID] != nil }
    }

    /// Loads stored vectors for these items (from a background thread, at launch).
    func load(itemIDs: [UUID], from store: IntelligenceVectorStore) {
        var loaded: [UUID: [Float]] = [:]
        for id in itemIDs {
            guard let data = store.load(kind: .searchVector, itemID: id) else { continue }
            loaded[id] = Self.decode(data)
        }
        lock.withLock { vectors.merge(loaded) { _, new in new } }
    }

    /// Items related to the query, best first, among `candidates`.
    func matches(for query: String, among candidates: [UUID]) -> [UUID] {
        guard let queryVector = Self.vector(for: query) else { return [] }
        let snapshot = lock.withLock { vectors }
        let scored = candidates.compactMap { id -> (UUID, Float)? in
            guard let vector = snapshot[id], vector.count == queryVector.count else { return nil }
            var dot: Float = 0
            for index in vector.indices { dot += vector[index] * queryVector[index] }
            return (id, dot)
        }.sorted { $0.1 > $1.1 }
        let background = scored.count > Self.backgroundRank ? scored[Self.backgroundRank].1 : Self.fallbackBackground
        let threshold = max(Self.minimumSimilarity, background + Self.minimumLeadOverBackground)
        return scored.prefix { $0.1 >= threshold }
            .prefix(Self.maximumResults)
            .map(\.0)
    }

    static func encode(_ vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    static func decode(_ data: Data) -> [Float] {
        data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}
