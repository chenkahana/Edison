import XCTest
@testable import Edison

final class EdisonTests: XCTestCase {
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
        let imageData = ClipboardImageData(data: Data([0x00]), thumbnailData: Data([0x00]))
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
        let imageData = ClipboardImageData(data: Data([0x00]), thumbnailData: Data([0x00]))
        let items = [
            ClipboardItem(payload: .text("Project Edison status")),
            ClipboardItem(payload: .image(imageData))
        ]

        let filtered = engine.filter(query: "screenshot", in: items, type: .image)
        XCTAssertEqual(filtered.count, 1)
    }
}
