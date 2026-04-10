import Foundation

final class HistoryStore {
    private struct HistorySnapshot: Codable {
        let items: [ClipboardItem]
        let collections: [ItemCollection]
    }

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let ioQueue = DispatchQueue(label: "edison.history.store", qos: .utility)

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = appSupport.appendingPathComponent("Edison", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("history.json")

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
        ioQueue.async { [fileURL, encoder] in
            guard let data = try? encoder.encode(snapshot) else { return }
            try? data.write(to: fileURL, options: [.atomic])
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
