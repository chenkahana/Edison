import Foundation

#if canImport(Testing)
import Testing
@testable import Edison

/// history.json is the user's whole clipboard history, so loading must never lose it silently:
/// older formats stay readable and an unreadable file is set aside, not overwritten.
struct HistoryStoreTests {
    private let stamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EdisonHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("A folder with no history loads as empty")
    func emptyLoad() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (items, collections) = HistoryStore(storageDirectory: directory).load()
        #expect(items.isEmpty)
        #expect(collections.isEmpty)
    }

    @Test("Items and collections survive a save and load, in order")
    func roundTrip() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = ClipboardItem(createdAt: stamp, isFavorite: true, payload: .text("first"))
        let second = ClipboardItem(createdAt: stamp, payload: .text("  second, with spaces\n"))
        let collection = ItemCollection(name: "Work", accentHex: "#FF9400", itemIDs: [first.id], createdAt: stamp)

        let store = HistoryStore(storageDirectory: directory)
        store.save(items: [first, second], collections: [collection])
        store.waitUntilIdle()

        let (items, collections) = HistoryStore(storageDirectory: directory).load()
        #expect(items.map(\.id) == [first.id, second.id])
        #expect(items.first?.isFavorite == true)
        #expect(items.last?.payload == .text("  second, with spaces\n"))
        #expect(collections == [collection])
    }

    @Test("The latest save replaces the previous one")
    func latestSaveWins() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HistoryStore(storageDirectory: directory)
        store.save(items: [makeTextItem("old")], collections: [])
        store.save(items: [makeTextItem("new")], collections: [])
        store.waitUntilIdle()

        let (items, _) = store.load()
        #expect(items.count == 1)
        #expect(items.first?.payload == .text("new"))
    }

    @Test("A history file from before collections, a bare array of items, still loads")
    func legacyArray() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let item = ClipboardItem(createdAt: stamp, payload: .text("legacy"))
        try JSONEncoder().encode([item]).write(to: directory.appendingPathComponent("history.json"))

        let (items, collections) = HistoryStore(storageDirectory: directory).load()
        #expect(items.map(\.id) == [item.id])
        #expect(collections.isEmpty)
    }

    @Test("An unreadable file is set aside as history.corrupt.json and the app starts empty")
    func corruptFileIsQuarantined() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let original = directory.appendingPathComponent("history.json")
        let garbage = Data("this is not json".utf8)
        try garbage.write(to: original)

        let (items, collections) = HistoryStore(storageDirectory: directory).load()
        #expect(items.isEmpty)
        #expect(collections.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: original.path))
        let kept = try Data(contentsOf: directory.appendingPathComponent("history.corrupt.json"))
        #expect(kept == garbage)
    }

    @Test("Async load delivers the saved history")
    func asyncLoad() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let item = ClipboardItem(createdAt: stamp, payload: .text("async"))
        let store = HistoryStore(storageDirectory: directory)
        store.save(items: [item], collections: [])
        store.waitUntilIdle()

        let loaded: [ClipboardItem] = await withCheckedContinuation { continuation in
            store.loadAsync { items, _ in continuation.resume(returning: items) }
        }
        #expect(loaded.map(\.id) == [item.id])
    }
}
#endif
