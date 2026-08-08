import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if canImport(Testing)
import Testing
@testable import Edison

struct ClipboardTests {
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

final class ClipboardTests: XCTestCase {
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
