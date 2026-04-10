import Foundation

final class HistoryStore {
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

    func loadAsync(_ completion: @escaping ([ClipboardItem]) -> Void) {
        ioQueue.async { [weak self] in
            guard let self else { return }
            let items = self.loadSync()
            DispatchQueue.main.async {
                completion(items)
            }
        }
    }

    func load() -> [ClipboardItem] {
        loadSync()
    }

    func save(_ items: [ClipboardItem]) {
        let snapshot = items
        ioQueue.async { [fileURL, encoder] in
            guard let data = try? encoder.encode(snapshot) else { return }
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    private func loadSync() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        do {
            return try decoder.decode([ClipboardItem].self, from: data)
        } catch {
            quarantineCorruptFile()
            return []
        }
    }

    private func quarantineCorruptFile() {
        let brokenURL = fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
        try? FileManager.default.removeItem(at: brokenURL)
        try? FileManager.default.moveItem(at: fileURL, to: brokenURL)
    }
}
