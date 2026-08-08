import Foundation
#if canImport(AppKit)
import AppKit
#endif

@testable import Edison

private enum FidelityTestError: Error {
    case pasteboardWriteFailed
    case missingCapture
}

private struct FidelityHarness {
    let root: URL
    let representationsDirectory: URL
    let historyDirectory: URL
    let pasteboard: NSPasteboard
    let representationStore: ClipboardRepresentationStore
    let historyStore: HistoryStore
    let monitor: ClipboardMonitor

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EdisonFidelityTests-\(UUID().uuidString)", isDirectory: true)
        representationsDirectory = root.appendingPathComponent("representations", isDirectory: true)
        historyDirectory = root.appendingPathComponent("history", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        pasteboard = NSPasteboard.withUniqueName()
        representationStore = ClipboardRepresentationStore(directoryURL: representationsDirectory)
        historyStore = HistoryStore(storageDirectory: historyDirectory)
        monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            representationStore: representationStore,
            sourceApplicationProvider: { nil }
        )
    }

    func cleanup() {
        monitor.stop()
        pasteboard.clearContents()
        pasteboard.releaseGlobally()
        try? FileManager.default.removeItem(at: root)
    }

    @MainActor
    func makeCoordinator() -> ClipboardCoordinator {
        let coordinator = ClipboardCoordinator(
            historyStore: historyStore,
            clipboardMonitor: monitor,
            representationStore: representationStore,
            pasteboard: pasteboard
        )
        coordinator.onPersistRequested = {}
        coordinator.onHistoryChanged = { _ in }
        coordinator.onItemDeleted = { _ in }
        coordinator.historyLimit = { 500 }
        return coordinator
    }

    func writeRichSource(
        html: Data,
        rtf: Data,
        rtfd: Data,
        plain: Data
    ) throws -> [String] {
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        guard item.setData(html, forType: .html),
              item.setData(rtf, forType: .rtf),
              item.setData(rtfd, forType: .rtfd),
              item.setData(plain, forType: .string),
              pasteboard.writeObjects([item]) else {
            throw FidelityTestError.pasteboardWriteFailed
        }
        let allowlist: Set<NSPasteboard.PasteboardType> = [.html, .rtf, .rtfd, .string]
        return item.types.filter { allowlist.contains($0) }.map(\.rawValue)
    }

    @MainActor
    func captureNextChange() async throws -> ClipboardItem {
        await withCheckedContinuation { continuation in
            monitor.start { item in
                continuation.resume(returning: item)
            }
            monitor.checkForChanges()
        }
    }
}

private let fidelityPlainText = "  alpha\tbeta  \nline two\n"
private let fidelityPlainData = Data(fidelityPlainText.utf8)
private let fidelityAttributedText: NSAttributedString = {
    let value = NSMutableAttributedString(string: fidelityPlainText)
    value.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 13), range: NSRange(location: 2, length: 5))
    return value
}()
private let fidelityHTMLData = try! fidelityAttributedText.data(
    from: NSRange(location: 0, length: fidelityAttributedText.length),
    documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
)
private let fidelityRTFData = try! fidelityAttributedText.data(
    from: NSRange(location: 0, length: fidelityAttributedText.length),
    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
)
private let fidelityRTFDData = try! fidelityAttributedText.data(
    from: NSRange(location: 0, length: fidelityAttributedText.length),
    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
)

#if canImport(Testing)
import Testing

struct ClipboardFidelityIntegrationTests {
    @MainActor
    @Test(
        "rich capture replays exact source bytes and plain mode leaves saved sidecars unchanged",
        .timeLimit(.minutes(1))
    )
    func richCaptureAndReplay() async throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }

        let sourceTypeIdentifiers = try harness.writeRichSource(
            html: fidelityHTMLData,
            rtf: fidelityRTFData,
            rtfd: fidelityRTFDData,
            plain: fidelityPlainData
        )
        let captured = try await harness.captureNextChange()
        guard case let .text(text) = captured.payload,
              let representations = captured.textRepresentations else {
            throw FidelityTestError.missingCapture
        }

        #expect(text == fidelityPlainText)
        #expect(representations.declaredTypeIdentifiers == sourceTypeIdentifiers)
        let capturedBytes = try Dictionary(uniqueKeysWithValues: representations.storedRepresentations.map {
            ($0.typeIdentifier, try harness.representationStore.load($0))
        })
        #expect(capturedBytes[NSPasteboard.PasteboardType.html.rawValue] == fidelityHTMLData)
        #expect(capturedBytes[NSPasteboard.PasteboardType.rtf.rawValue] == fidelityRTFData)
        #expect(capturedBytes[NSPasteboard.PasteboardType.rtfd.rawValue] == fidelityRTFDData)
        #expect(capturedBytes[NSPasteboard.PasteboardType.string.rawValue] == fidelityPlainData)

        let coordinator = harness.makeCoordinator()
        coordinator.addToHistory(captured, source: .internalAction)
        #expect(coordinator.writeItemToClipboard(captured, mode: .sourceFormatting))
        #expect(harness.pasteboard.pasteboardItems?.count == 1)
        let replayedAllowlistedTypes = harness.pasteboard.pasteboardItems?.first?.types.filter {
            [.html, .rtf, .rtfd, .string].contains($0)
        }
        #expect(replayedAllowlistedTypes?.map(\.rawValue) == sourceTypeIdentifiers)
        #expect(harness.pasteboard.pasteboardItems?.first?.data(forType: .html) == fidelityHTMLData)
        #expect(harness.pasteboard.pasteboardItems?.first?.data(forType: .rtf) == fidelityRTFData)
        #expect(harness.pasteboard.pasteboardItems?.first?.data(forType: .rtfd) == fidelityRTFDData)
        #expect(harness.pasteboard.pasteboardItems?.first?.data(forType: .string) == fidelityPlainData)
        let destinationValue = try #require(
            harness.pasteboard.readObjects(forClasses: [NSAttributedString.self], options: nil)?.first
                as? NSAttributedString
        )
        #expect(destinationValue.string == fidelityPlainText)
        let destinationFont = destinationValue.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        #expect(destinationFont?.fontDescriptor.symbolicTraits.contains(.bold) == true)

        #expect(coordinator.writeItemToClipboard(captured, mode: .plainText))
        #expect(harness.pasteboard.pasteboardItems?.count == 1)
        #expect(harness.pasteboard.pasteboardItems?.first?.types == [.string])
        #expect(harness.pasteboard.pasteboardItems?.first?.string(forType: .string) == fidelityPlainText)
        #expect(captured.textRepresentations == representations)
        for descriptor in representations.storedRepresentations {
            #expect(try harness.representationStore.load(descriptor) == capturedBytes[descriptor.typeIdentifier])
        }
    }

    @MainActor
    @Test("history restart preserves rich sidecars for replay", .timeLimit(.minutes(1)))
    func restartPersistence() async throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }

        _ = try harness.writeRichSource(
            html: fidelityHTMLData,
            rtf: fidelityRTFData,
            rtfd: fidelityRTFDData,
            plain: fidelityPlainData
        )
        let captured = try await harness.captureNextChange()
        harness.historyStore.save(items: [captured], collections: [])
        harness.historyStore.waitUntilIdle()

        let restartedStore = HistoryStore(storageDirectory: harness.historyDirectory)
        let loaded = restartedStore.load().0
        #expect(loaded.count == 1)
        let coordinator = ClipboardCoordinator(
            historyStore: restartedStore,
            clipboardMonitor: harness.monitor,
            representationStore: harness.representationStore,
            pasteboard: harness.pasteboard
        )
        #expect(coordinator.writeItemToClipboard(loaded[0], mode: .sourceFormatting))
        #expect(harness.pasteboard.pasteboardItems?.first?.data(forType: .html) == fidelityHTMLData)
        #expect(harness.pasteboard.pasteboardItems?.first?.data(forType: .rtf) == fidelityRTFData)
        #expect(harness.pasteboard.pasteboardItems?.first?.data(forType: .rtfd) == fidelityRTFDData)
        #expect(harness.pasteboard.pasteboardItems?.first?.data(forType: .string) == fidelityPlainData)
    }

    @Test("literal pre-2.0 history decodes without textRepresentations")
    func legacyHistoryDecode() throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }
        let legacy = #"[{"id":"00000000-0000-0000-0000-000000000026","createdAt":0,"isFavorite":false,"payload":{"text":{"_0":"legacy text"}}}]"#
        try Data(legacy.utf8).write(
            to: harness.historyDirectory.appendingPathComponent("history.json"),
            options: .atomic
        )

        let items = harness.historyStore.load().0
        #expect(items.count == 1)
        #expect(items[0].payload == .text("legacy text"))
        #expect(items[0].textRepresentations == nil)
    }

    @MainActor
    @Test("missing or corrupt rich sidecars fall back to exact canonical plain text")
    func unavailableSidecarFallback() throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }
        let coordinator = harness.makeCoordinator()

        for corrupt in [false, true] {
            let representations = harness.representationStore.save(
                representations: [(NSPasteboard.PasteboardType.rtf.rawValue, fidelityRTFData)],
                declaredTypeIdentifiers: [
                    NSPasteboard.PasteboardType.rtf.rawValue,
                    NSPasteboard.PasteboardType.string.rawValue
                ],
                itemID: UUID()
            )
            let descriptor = try #require(representations.storedRepresentations.first)
            let url = harness.representationsDirectory.appendingPathComponent(descriptor.relativePath)
            if corrupt {
                try Data("corrupt".utf8).write(to: url, options: .atomic)
            } else {
                try FileManager.default.removeItem(at: url)
            }
            let item = ClipboardItem(
                payload: .text(fidelityPlainText),
                textRepresentations: representations
            )

            #expect(coordinator.writeItemToClipboard(item, mode: .sourceFormatting))
            #expect(harness.pasteboard.pasteboardItems?.first?.types == [.string])
            #expect(harness.pasteboard.pasteboardItems?.first?.string(forType: .string) == fidelityPlainText)
        }
    }

    @Test("representation delete and reconcile cleanup complete deterministically")
    func representationCleanup() throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }

        let deleted = harness.representationStore.save(
            representations: [(NSPasteboard.PasteboardType.rtf.rawValue, fidelityRTFData)],
            declaredTypeIdentifiers: [NSPasteboard.PasteboardType.rtf.rawValue],
            itemID: UUID()
        )
        let deletedPath = try #require(deleted.storedRepresentations.first?.relativePath)
        harness.representationStore.delete(deleted)
        harness.representationStore.waitUntilIdle()
        #expect(!FileManager.default.fileExists(
            atPath: harness.representationsDirectory.appendingPathComponent(deletedPath).path
        ))

        let live = harness.representationStore.save(
            representations: [(NSPasteboard.PasteboardType.html.rawValue, fidelityHTMLData)],
            declaredTypeIdentifiers: [NSPasteboard.PasteboardType.html.rawValue],
            itemID: UUID()
        )
        let stale = harness.representationStore.save(
            representations: [(NSPasteboard.PasteboardType.rtf.rawValue, fidelityRTFData)],
            declaredTypeIdentifiers: [NSPasteboard.PasteboardType.rtf.rawValue],
            itemID: UUID()
        )
        let livePath = try #require(live.storedRepresentations.first?.relativePath)
        let stalePath = try #require(stale.storedRepresentations.first?.relativePath)
        harness.representationStore.reconcile(items: [
            ClipboardItem(payload: .text("live"), textRepresentations: live)
        ])
        harness.representationStore.waitUntilIdle()
        #expect(FileManager.default.fileExists(
            atPath: harness.representationsDirectory.appendingPathComponent(livePath).path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: harness.representationsDirectory.appendingPathComponent(stalePath).path
        ))
    }

    @MainActor
    @Test("paste-back forwards both clipboard write modes")
    func pasteBackModes() {
        let item = ClipboardItem(payload: .text("mode"))
        var modes: [ClipboardWriteMode] = []
        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _, mode in
                modes.append(mode)
                return true
            },
            isAccessibilityTrusted: { true },
            closeHub: {}
        )

        coordinator.run(item: item, targetApp: nil, mode: .sourceFormatting)
        coordinator.run(item: item, targetApp: nil, mode: .plainText)
        #expect(modes == [.sourceFormatting, .plainText])
    }

    @MainActor
    @Test(
        "self-write observation does not suppress a later external same-text copy",
        .timeLimit(.minutes(1))
    )
    func selfWriteThenExternalSameText() async throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }
        let coordinator = harness.makeCoordinator()
        let original = ClipboardItem(payload: .text(fidelityPlainText))
        coordinator.addToHistory(original, source: .internalAction)
        #expect(coordinator.writeItemToClipboard(original))

        let externalID = await withCheckedContinuation { continuation in
            harness.monitor.start { item in
                coordinator.addToHistory(item, source: .clipboard)
                continuation.resume(returning: item.id)
            }
            harness.pasteboard.clearContents()
            harness.pasteboard.setString(fidelityPlainText, forType: .string)
            harness.monitor.checkForChanges()
        }

        #expect(coordinator.historyItems.first?.id == externalID)
        #expect(coordinator.historyItems.first?.id != original.id)
    }

    @MainActor
    @Test("Shift-Return and Shift-keypad-Enter route to plain paste")
    func plainPasteKeyRouting() {
        #expect(HubWindowAccessor.confirmMode(keyCode: 36, modifierFlags: [.shift]) == .plainText)
        #expect(HubWindowAccessor.confirmMode(keyCode: 76, modifierFlags: [.shift, .numericPad]) == .plainText)
        #expect(HubWindowAccessor.confirmMode(keyCode: 36, modifierFlags: []) == .sourceFormatting)
        #expect(HubWindowAccessor.confirmMode(keyCode: 36, modifierFlags: [.command]) == nil)
        #expect(HubWindowAccessor.confirmMode(keyCode: 49, modifierFlags: [.shift]) == nil)
    }
}

#elseif canImport(XCTest)
import XCTest

final class ClipboardFidelityIntegrationTests: XCTestCase {
    @MainActor
    func testRichCaptureAndReplay() async throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }
        let sourceTypeIdentifiers = try harness.writeRichSource(
            html: fidelityHTMLData,
            rtf: fidelityRTFData,
            rtfd: fidelityRTFDData,
            plain: fidelityPlainData
        )
        let captured = try await harness.captureNextChange()
        guard case let .text(text) = captured.payload,
              let representations = captured.textRepresentations else {
            throw FidelityTestError.missingCapture
        }
        XCTAssertEqual(text, fidelityPlainText)
        XCTAssertEqual(representations.declaredTypeIdentifiers, sourceTypeIdentifiers)
        let coordinator = harness.makeCoordinator()
        XCTAssertTrue(coordinator.writeItemToClipboard(captured, mode: .sourceFormatting))
        XCTAssertEqual(harness.pasteboard.pasteboardItems?.first?.data(forType: .html), fidelityHTMLData)
        XCTAssertEqual(harness.pasteboard.pasteboardItems?.first?.data(forType: .rtf), fidelityRTFData)
        XCTAssertEqual(harness.pasteboard.pasteboardItems?.first?.data(forType: .rtfd), fidelityRTFDData)
        XCTAssertTrue(coordinator.writeItemToClipboard(captured, mode: .plainText))
        XCTAssertEqual(harness.pasteboard.pasteboardItems?.first?.types, [.string])
        XCTAssertEqual(harness.pasteboard.pasteboardItems?.first?.string(forType: .string), fidelityPlainText)
    }

    @MainActor
    func testRestartPersistence() async throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }
        _ = try harness.writeRichSource(
            html: fidelityHTMLData,
            rtf: fidelityRTFData,
            rtfd: fidelityRTFDData,
            plain: fidelityPlainData
        )
        let captured = try await harness.captureNextChange()
        harness.historyStore.save(items: [captured], collections: [])
        harness.historyStore.waitUntilIdle()
        let loaded = HistoryStore(storageDirectory: harness.historyDirectory).load().0
        XCTAssertEqual(loaded.count, 1)
        let coordinator = harness.makeCoordinator()
        XCTAssertTrue(coordinator.writeItemToClipboard(loaded[0], mode: .sourceFormatting))
        XCTAssertEqual(harness.pasteboard.pasteboardItems?.first?.data(forType: .html), fidelityHTMLData)
    }

    func testLegacyHistoryDecode() throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }
        let legacy = #"[{"id":"00000000-0000-0000-0000-000000000026","createdAt":0,"isFavorite":false,"payload":{"text":{"_0":"legacy text"}}}]"#
        try Data(legacy.utf8).write(
            to: harness.historyDirectory.appendingPathComponent("history.json"),
            options: .atomic
        )
        let items = harness.historyStore.load().0
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].payload, .text("legacy text"))
        XCTAssertNil(items[0].textRepresentations)
    }

    @MainActor
    func testUnavailableSidecarFallback() throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }
        let coordinator = harness.makeCoordinator()
        let representations = harness.representationStore.save(
            representations: [(NSPasteboard.PasteboardType.rtf.rawValue, fidelityRTFData)],
            declaredTypeIdentifiers: [
                NSPasteboard.PasteboardType.rtf.rawValue,
                NSPasteboard.PasteboardType.string.rawValue
            ],
            itemID: UUID()
        )
        let descriptor = try XCTUnwrap(representations.storedRepresentations.first)
        try FileManager.default.removeItem(
            at: harness.representationsDirectory.appendingPathComponent(descriptor.relativePath)
        )
        let item = ClipboardItem(payload: .text(fidelityPlainText), textRepresentations: representations)
        XCTAssertTrue(coordinator.writeItemToClipboard(item, mode: .sourceFormatting))
        XCTAssertEqual(harness.pasteboard.pasteboardItems?.first?.types, [.string])
        XCTAssertEqual(harness.pasteboard.pasteboardItems?.first?.string(forType: .string), fidelityPlainText)
    }

    func testRepresentationCleanup() throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }
        let representations = harness.representationStore.save(
            representations: [(NSPasteboard.PasteboardType.rtf.rawValue, fidelityRTFData)],
            declaredTypeIdentifiers: [NSPasteboard.PasteboardType.rtf.rawValue],
            itemID: UUID()
        )
        let path = try XCTUnwrap(representations.storedRepresentations.first?.relativePath)
        harness.representationStore.delete(representations)
        harness.representationStore.waitUntilIdle()
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: harness.representationsDirectory.appendingPathComponent(path).path
        ))
    }

    @MainActor
    func testPasteBackModes() {
        let item = ClipboardItem(payload: .text("mode"))
        var modes: [ClipboardWriteMode] = []
        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _, mode in
                modes.append(mode)
                return true
            },
            isAccessibilityTrusted: { true },
            closeHub: {}
        )
        coordinator.run(item: item, targetApp: nil, mode: .sourceFormatting)
        coordinator.run(item: item, targetApp: nil, mode: .plainText)
        XCTAssertEqual(modes, [.sourceFormatting, .plainText])
    }

    @MainActor
    func testSelfWriteThenExternalSameText() async throws {
        let harness = try FidelityHarness()
        defer { harness.cleanup() }
        let coordinator = harness.makeCoordinator()
        let original = ClipboardItem(payload: .text(fidelityPlainText))
        coordinator.addToHistory(original, source: .internalAction)
        XCTAssertTrue(coordinator.writeItemToClipboard(original))
        let externalID = await withCheckedContinuation { continuation in
            harness.monitor.start { item in
                coordinator.addToHistory(item, source: .clipboard)
                continuation.resume(returning: item.id)
            }
            harness.pasteboard.clearContents()
            harness.pasteboard.setString(fidelityPlainText, forType: .string)
            harness.monitor.checkForChanges()
        }
        XCTAssertEqual(coordinator.historyItems.first?.id, externalID)
        XCTAssertNotEqual(coordinator.historyItems.first?.id, original.id)
    }
}
#endif
