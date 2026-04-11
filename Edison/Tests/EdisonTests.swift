import Foundation
#if canImport(AppKit)
import AppKit
#endif

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

    @Test("Clipboard monitor skips transient pasteboard content")
    func clipboardMonitorSkipsTransientType() {
        let monitor = ClipboardMonitor()
        let types = [NSPasteboard.PasteboardType("org.nspasteboard.TransientType")]

        #expect(monitor.shouldSkipStorage(for: types))
    }

    @Test("Clipboard monitor skips concealed pasteboard content")
    func clipboardMonitorSkipsConcealedType() {
        let monitor = ClipboardMonitor()
        let types = [NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")]

        #expect(monitor.shouldSkipStorage(for: types))
    }

    @Test("Clipboard monitor stores regular pasteboard content")
    func clipboardMonitorStoresRegularType() {
        let monitor = ClipboardMonitor()
        let types = [NSPasteboard.PasteboardType.string]

        #expect(!monitor.shouldSkipStorage(for: types))
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

    @Test("Clipboard item source application survives codable roundtrips")
    func clipboardItemSourceApplicationRoundTrip() {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        let withSource = ClipboardItem(
            sourceApplication: ClipboardSourceApplication(
                bundleIdentifier: "com.apple.Safari",
                localizedName: "Safari"
            ),
            payload: .text("Hello Edison")
        )
        let withoutSource = ClipboardItem(payload: .text("Fallback"))

        let withSourceData = try! encoder.encode(withSource)
        let withoutSourceData = try! encoder.encode(withoutSource)

        let decodedWithSource = try! decoder.decode(ClipboardItem.self, from: withSourceData)
        let decodedWithoutSource = try! decoder.decode(ClipboardItem.self, from: withoutSourceData)

        #expect(decodedWithSource.sourceApplication?.bundleIdentifier == "com.apple.Safari")
        #expect(decodedWithoutSource.sourceApplication == nil)
    }

    @Test("Compact relative timestamp formatter uses short units")
    func compactRelativeTimestampFormatter() {
        let reference = Date(timeIntervalSince1970: 1_000_000)

        #expect(HubRelativeTimeFormatter.string(for: reference.addingTimeInterval(-30), relativeTo: reference) == "now")
        #expect(HubRelativeTimeFormatter.string(for: reference.addingTimeInterval(-120), relativeTo: reference) == "2m")
        #expect(HubRelativeTimeFormatter.string(for: reference.addingTimeInterval(-10_800), relativeTo: reference) == "3h")
        #expect(HubRelativeTimeFormatter.string(for: reference.addingTimeInterval(-345_600), relativeTo: reference) == "4d")
    }

    @Test("Structured text formatter pretty prints JSON")
    func structuredTextFormatterPrettyPrintsJSON() {
        let formatted = HubStructuredTextFormatter.prettyPrintedJSON(from: #"{"b":1,"a":{"c":2}}"#)

        #expect(formatted == """
        {
          "a" : {
            "c" : 2
          },
          "b" : 1
        }
        """)
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

    func testClipboardItemSourceApplicationRoundTrip() throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        let withSource = ClipboardItem(
            sourceApplication: ClipboardSourceApplication(
                bundleIdentifier: "com.apple.Safari",
                localizedName: "Safari"
            ),
            payload: .text("Hello Edison")
        )
        let withoutSource = ClipboardItem(payload: .text("Fallback"))

        let withSourceData = try encoder.encode(withSource)
        let withoutSourceData = try encoder.encode(withoutSource)

        let decodedWithSource = try decoder.decode(ClipboardItem.self, from: withSourceData)
        let decodedWithoutSource = try decoder.decode(ClipboardItem.self, from: withoutSourceData)

        XCTAssertEqual(decodedWithSource.sourceApplication?.bundleIdentifier, "com.apple.Safari")
        XCTAssertNil(decodedWithoutSource.sourceApplication)
    }

    func testCompactRelativeTimestampFormatter() {
        let reference = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(HubRelativeTimeFormatter.string(for: reference.addingTimeInterval(-30), relativeTo: reference), "now")
        XCTAssertEqual(HubRelativeTimeFormatter.string(for: reference.addingTimeInterval(-120), relativeTo: reference), "2m")
        XCTAssertEqual(HubRelativeTimeFormatter.string(for: reference.addingTimeInterval(-10_800), relativeTo: reference), "3h")
        XCTAssertEqual(HubRelativeTimeFormatter.string(for: reference.addingTimeInterval(-345_600), relativeTo: reference), "4d")
    }

    func testStructuredTextFormatterPrettyPrintsJSON() {
        let formatted = HubStructuredTextFormatter.prettyPrintedJSON(from: #"{"b":1,"a":{"c":2}}"#)

        XCTAssertEqual(formatted, """
        {
          "a" : {
            "c" : 2
          },
          "b" : 1
        }
        """)
    }
}
#endif
