import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if canImport(Testing)
import Testing
@testable import Edison

struct ClipboardCoordinatorTests {

    // MARK: - Helpers

    @MainActor
    private func makeCoordinator() -> ClipboardCoordinator {
        let coordinator = ClipboardCoordinator(
            historyStore: HistoryStore(),
            clipboardMonitor: ClipboardMonitor()
        )
        // Wire a no-op persist so tests don't write to disk.
        coordinator.onPersistRequested = {}
        coordinator.onHistoryChanged = { _ in }
        coordinator.onItemDeleted = { _ in }
        coordinator.historyLimit = { 500 }
        return coordinator
    }

    // MARK: - W4b.1 Test 1: addToHistory dedupes suppressed payloads

    @MainActor
    @Test("addToHistory skips items whose payload is in suppressedClipboardPayloads")
    func addToHistoryDedupesSuppressedPayload() {
        let coordinator = makeCoordinator()
        let item = ClipboardItem(payload: .text("suppressed-unique"))

        // Simulate a clipboard write: suppress the payload.
        coordinator.suppressPayload(item.payload)

        // Now addToHistory with source .clipboard should skip it.
        coordinator.addToHistory(item, source: .clipboard)

        #expect(coordinator.historyItems.isEmpty,
                "Item whose payload was suppressed must not be added to history")
        #expect(coordinator.suppressedClipboardPayloads.isEmpty,
                "Suppressed payload must be consumed (removed) on first match")
    }

    // MARK: - W4b.1 Test 2: deleteItem removes, undoDelete restores to front

    @MainActor
    @Test("deleteItem removes item and undoDelete restores it to front")
    func deleteItemAndUndoDeleteRestoresItem() {
        let coordinator = makeCoordinator()
        let alpha = ClipboardItem(payload: .text("alpha-unique"))
        let beta  = ClipboardItem(payload: .text("beta-unique"))

        coordinator.addToHistory(alpha, source: .internalAction)
        coordinator.addToHistory(beta,  source: .internalAction)
        // After two inserts at front: [beta, alpha]
        #expect(coordinator.historyItems.count == 2)

        coordinator.deleteItem(itemID: alpha.id)
        #expect(coordinator.historyItems.count == 1)
        #expect(coordinator.historyItems.first?.id == beta.id,
                "Only beta should remain after deleting alpha")
        #expect(coordinator.deletedItemForUndo?.id == alpha.id,
                "deletedItemForUndo must be set to the deleted item")
        #expect(coordinator.showDeleteUndoToast,
                "showDeleteUndoToast must be true immediately after delete")

        coordinator.undoDelete()
        #expect(coordinator.historyItems.count == 2,
                "undoDelete must restore the item")
        #expect(coordinator.historyItems.first?.id == alpha.id,
                "Restored item must be inserted at front")
        #expect(coordinator.deletedItemForUndo == nil,
                "deletedItemForUndo must be cleared after undo")
        #expect(!coordinator.showDeleteUndoToast,
                "showDeleteUndoToast must be cleared after undo")
    }

    // MARK: - W4b.1 Test 3: toggleFavorite flips the flag

    @MainActor
    @Test("toggleFavorite flips isFavorite on the target item")
    func toggleFavoriteFlipsFlag() {
        let coordinator = makeCoordinator()
        let item = ClipboardItem(isFavorite: false, payload: .text("fav-test-unique"))

        coordinator.addToHistory(item, source: .internalAction)

        let before = coordinator.historyItems.first(where: { $0.id == item.id })?.isFavorite
        #expect(before == false, "Item must start as not favorite")

        coordinator.toggleFavorite(itemID: item.id)
        let after = coordinator.historyItems.first(where: { $0.id == item.id })?.isFavorite
        #expect(after == true, "isFavorite must be true after first toggle")

        coordinator.toggleFavorite(itemID: item.id)
        let afterSecond = coordinator.historyItems.first(where: { $0.id == item.id })?.isFavorite
        #expect(afterSecond == false, "isFavorite must be false after second toggle")
    }
}

#elseif canImport(XCTest)
import XCTest
@testable import Edison

final class ClipboardCoordinatorTests: XCTestCase {

    // MARK: - Helpers

    @MainActor
    private func makeCoordinator() -> ClipboardCoordinator {
        let coordinator = ClipboardCoordinator(
            historyStore: HistoryStore(),
            clipboardMonitor: ClipboardMonitor()
        )
        coordinator.onPersistRequested = {}
        coordinator.onHistoryChanged = { _ in }
        coordinator.onItemDeleted = { _ in }
        coordinator.historyLimit = { 500 }
        return coordinator
    }

    // MARK: - W4b.1 Test 1: addToHistory dedupes suppressed payloads

    @MainActor
    func testAddToHistoryDedupesSuppressedPayload() {
        let coordinator = makeCoordinator()
        let item = ClipboardItem(payload: .text("suppressed-unique"))

        coordinator.suppressPayload(item.payload)
        coordinator.addToHistory(item, source: .clipboard)

        XCTAssertTrue(coordinator.historyItems.isEmpty,
                      "Item whose payload was suppressed must not be added to history")
        XCTAssertTrue(coordinator.suppressedClipboardPayloads.isEmpty,
                      "Suppressed payload must be consumed (removed) on first match")
    }

    // MARK: - W4b.1 Test 2: deleteItem removes, undoDelete restores to front

    @MainActor
    func testDeleteItemAndUndoDeleteRestoresItem() {
        let coordinator = makeCoordinator()
        let alpha = ClipboardItem(payload: .text("alpha-unique"))
        let beta  = ClipboardItem(payload: .text("beta-unique"))

        coordinator.addToHistory(alpha, source: .internalAction)
        coordinator.addToHistory(beta,  source: .internalAction)
        XCTAssertEqual(coordinator.historyItems.count, 2)

        coordinator.deleteItem(itemID: alpha.id)
        XCTAssertEqual(coordinator.historyItems.count, 1)
        XCTAssertEqual(coordinator.historyItems.first?.id, beta.id)
        XCTAssertEqual(coordinator.deletedItemForUndo?.id, alpha.id)
        XCTAssertTrue(coordinator.showDeleteUndoToast)

        coordinator.undoDelete()
        XCTAssertEqual(coordinator.historyItems.count, 2)
        XCTAssertEqual(coordinator.historyItems.first?.id, alpha.id,
                       "Restored item must be inserted at front")
        XCTAssertNil(coordinator.deletedItemForUndo)
        XCTAssertFalse(coordinator.showDeleteUndoToast)
    }

    // MARK: - W4b.1 Test 3: toggleFavorite flips the flag

    @MainActor
    func testToggleFavoriteFlipsFlag() {
        let coordinator = makeCoordinator()
        let item = ClipboardItem(isFavorite: false, payload: .text("fav-test-unique"))

        coordinator.addToHistory(item, source: .internalAction)

        XCTAssertFalse(coordinator.historyItems.first(where: { $0.id == item.id })?.isFavorite ?? true)

        coordinator.toggleFavorite(itemID: item.id)
        XCTAssertTrue(coordinator.historyItems.first(where: { $0.id == item.id })?.isFavorite ?? false,
                      "isFavorite must be true after first toggle")

        coordinator.toggleFavorite(itemID: item.id)
        XCTAssertFalse(coordinator.historyItems.first(where: { $0.id == item.id })?.isFavorite ?? true,
                       "isFavorite must be false after second toggle")
    }
}
#endif
