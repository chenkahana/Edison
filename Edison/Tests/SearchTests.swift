import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if canImport(Testing)
import Testing
@testable import Edison

struct SearchTests {
    @Test("Search filters text items")
    func searchFiltersTextItems() {
        let engine = HistorySearchEngine()
        let items = [
            ClipboardItem(payload: .text("Hello Edison")),
            ClipboardItem(payload: .text("Another value"))
        ]

        let filtered = engine.filter(query: "edi", in: items)
        #expect(filtered.count == 1)
    }

    @Test("Search matches file name")
    func searchMatchesFileName() {
        let engine = HistorySearchEngine()
        let items = [
            ClipboardItem(payload: .fileURL(URL(fileURLWithPath: "/tmp/contract.pdf"))),
            ClipboardItem(payload: .fileURL(URL(fileURLWithPath: "/tmp/note.txt")))
        ]

        let filtered = engine.filter(query: "contract", in: items)
        #expect(filtered.count == 1)
    }

    @Test("Type filter returns only text items")
    func typeFilterReturnsOnlyTextItems() {
        let engine = HistorySearchEngine()
        let imageData = ClipboardImageData(imagePath: "stub.png", thumbnailPath: "stub-thumb.png")
        let items = [
            ClipboardItem(payload: .text("First note")),
            ClipboardItem(payload: .image(imageData)),
            ClipboardItem(payload: .text("Second note"))
        ]

        let filtered = engine.filter(query: "", in: items, type: .text)
        #expect(filtered.count == 2)
    }

    @Test("Type filter composes with search query")
    func typeFilterAndQueryTogether() {
        let engine = HistorySearchEngine()
        let imageData = ClipboardImageData(imagePath: "stub.png", thumbnailPath: "stub-thumb.png")
        let items = [
            ClipboardItem(payload: .text("Project Edison status")),
            ClipboardItem(payload: .image(imageData))
        ]

        let filtered = engine.filter(query: "screenshot", in: items, type: .image)
        #expect(filtered.count == 1)
    }
}
#elseif canImport(XCTest)
import XCTest
@testable import Edison

final class SearchTests: XCTestCase {
    func testSearchFiltersTextItems() {
        let engine = HistorySearchEngine()
        let items = [
            ClipboardItem(payload: .text("Hello Edison")),
            ClipboardItem(payload: .text("Another value"))
        ]

        let filtered = engine.filter(query: "edi", in: items)
        XCTAssertEqual(filtered.count, 1)
    }

    func testSearchMatchesFileName() {
        let engine = HistorySearchEngine()
        let items = [
            ClipboardItem(payload: .fileURL(URL(fileURLWithPath: "/tmp/contract.pdf"))),
            ClipboardItem(payload: .fileURL(URL(fileURLWithPath: "/tmp/note.txt")))
        ]

        let filtered = engine.filter(query: "contract", in: items)
        XCTAssertEqual(filtered.count, 1)
    }

    func testTypeFilterReturnsOnlyTextItems() {
        let engine = HistorySearchEngine()
        let imageData = ClipboardImageData(imagePath: "stub.png", thumbnailPath: "stub-thumb.png")
        let items = [
            ClipboardItem(payload: .text("First note")),
            ClipboardItem(payload: .image(imageData)),
            ClipboardItem(payload: .text("Second note"))
        ]

        let filtered = engine.filter(query: "", in: items, type: .text)
        XCTAssertEqual(filtered.count, 2)
    }

    func testTypeFilterAndQueryTogether() {
        let engine = HistorySearchEngine()
        let imageData = ClipboardImageData(imagePath: "stub.png", thumbnailPath: "stub-thumb.png")
        let items = [
            ClipboardItem(payload: .text("Project Edison status")),
            ClipboardItem(payload: .image(imageData))
        ]

        let filtered = engine.filter(query: "screenshot", in: items, type: .image)
        XCTAssertEqual(filtered.count, 1)
    }
}
#endif
