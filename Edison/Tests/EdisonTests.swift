import Foundation

#if canImport(Testing)
import Testing
@testable import Edison

struct EdisonTests {
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
}
#elseif canImport(XCTest)
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

    func testClipboardMonitorSkipsTransientType() {
        let monitor = ClipboardMonitor()
        let types = [NSPasteboard.PasteboardType("org.nspasteboard.TransientType")]

        XCTAssertTrue(monitor.shouldSkipStorage(for: types))
    }

    func testClipboardMonitorSkipsConcealedType() {
        let monitor = ClipboardMonitor()
        let types = [NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")]

        XCTAssertTrue(monitor.shouldSkipStorage(for: types))
    }

    func testClipboardMonitorStoresRegularType() {
        let monitor = ClipboardMonitor()
        let types = [NSPasteboard.PasteboardType.string]

        XCTAssertFalse(monitor.shouldSkipStorage(for: types))
    }
}
#endif
