import Foundation
import OSLog

private struct HistorySnapshot: Codable {
    let items: [ClipboardItem]
    let collections: [ItemCollection]
}

final class HistoryStore {
    static let storageDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = appSupport.appendingPathComponent("Edison", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let ioQueue = DispatchQueue(label: "edison.history.store", qos: .utility)

    init(fileManager: FileManager = .default) {
        try? fileManager.createDirectory(at: Self.storageDirectory, withIntermediateDirectories: true)
        fileURL = Self.storageDirectory.appendingPathComponent("history.json")

        encoder.outputFormatting = [.prettyPrinted]
    }

    func loadAsync(_ completion: @escaping ([ClipboardItem], [ItemCollection]) -> Void) {
        ioQueue.async { [weak self] in
            guard let self else { return }
            let snapshot = self.loadSync()
            DispatchQueue.main.async {
                completion(snapshot.items, snapshot.collections)
            }
        }
    }

    func load() -> ([ClipboardItem], [ItemCollection]) {
        let snapshot = loadSync()
        return (snapshot.items, snapshot.collections)
    }

    func save(items: [ClipboardItem], collections: [ItemCollection]) {
        let snapshot = HistorySnapshot(items: items, collections: collections)
        guard let data = try? encoder.encode(snapshot) else {
            Log.store.error("HistoryStore: failed to encode snapshot")
            return
        }

        ioQueue.async { [fileURL] in
            do {
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                Log.store.error("HistoryStore: save failed – \(error.localizedDescription)")
            }
        }
    }

    private func loadSync() -> HistorySnapshot {
        guard let data = try? Data(contentsOf: fileURL) else {
            return HistorySnapshot(items: [], collections: [])
        }

        do {
            return try decoder.decode(HistorySnapshot.self, from: data)
        } catch {
            // Backward compatibility for older versions that stored only clipboard items.
            if let legacyItems = try? decoder.decode([ClipboardItem].self, from: data) {
                return HistorySnapshot(items: legacyItems, collections: [])
            }

            quarantineCorruptFile()
            return HistorySnapshot(items: [], collections: [])
        }
    }

    private func quarantineCorruptFile() {
        let brokenURL = fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
        try? FileManager.default.removeItem(at: brokenURL)
        try? FileManager.default.moveItem(at: fileURL, to: brokenURL)
    }
}
