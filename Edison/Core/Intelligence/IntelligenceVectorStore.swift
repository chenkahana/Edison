import Foundation
import OSLog

/// Binary sidecars for per-item vectors (image feature prints, and later text embeddings), kept out
/// of history.json so saving history stays cheap. One file per item and vector kind, in
/// `{AppSupport}/Edison/intelligence/`. Deleted with the item, and orphans are removed at launch.
final class IntelligenceVectorStore: @unchecked Sendable {
    enum Kind: String, CaseIterable {
        /// An archived `VNFeaturePrintObservation`.
        case featurePrint = "featureprint"
    }

    static let shared = IntelligenceVectorStore()

    private let directory: URL
    private let queue = DispatchQueue(label: "edison.intelligence.vectors", qos: .utility)

    init(directory: URL = HistoryStore.storageDirectory.appendingPathComponent("intelligence", isDirectory: true)) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(_ kind: Kind, _ itemID: UUID) -> URL {
        directory.appendingPathComponent("\(itemID.uuidString).\(kind.rawValue)")
    }

    func save(_ data: Data, kind: Kind, itemID: UUID) {
        let url = url(kind, itemID)
        queue.async {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                Log.intelligence.error("Vector save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func load(kind: Kind, itemID: UUID) -> Data? {
        let url = url(kind, itemID)
        return queue.sync { try? Data(contentsOf: url) }
    }

    /// For an identical re-copy, which keeps the earlier item's metadata under a new ID.
    func copy(from sourceID: UUID, to destinationID: UUID) {
        let pairs = Kind.allCases.map { (url($0, sourceID), url($0, destinationID)) }
        queue.async {
            for (source, destination) in pairs where FileManager.default.fileExists(atPath: source.path) {
                try? FileManager.default.removeItem(at: destination)
                try? FileManager.default.copyItem(at: source, to: destination)
            }
        }
    }

    func delete(itemID: UUID) {
        let urls = Kind.allCases.map { url($0, itemID) }
        queue.async {
            urls.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }

    func reconcile(liveItemIDs: Set<UUID>) {
        let directory = self.directory
        queue.async {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            for name in names {
                guard let id = UUID(uuidString: String(name.prefix(while: { $0 != "." }))),
                      !liveItemIDs.contains(id) else { continue }
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
            }
        }
    }

    func waitUntilIdle() {
        queue.sync {}
    }
}
