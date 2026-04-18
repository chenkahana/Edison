import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if canImport(Testing)
import Testing
import Carbon
@testable import Edison

private func makeTextItem(_ value: String) -> ClipboardItem {
    ClipboardItem(payload: .text(value))
}

private func makeTestImageData(size: NSSize = NSSize(width: 80, height: 60)) -> Data {
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
    image.unlockFocus()

    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

private enum LegacyShortcutActionTest: String, Codable, Hashable {
    case openHub
    case captureArea
    case captureWindow
    case captureFullScreen
}

private struct LegacyShortcutSetTest: Codable, Hashable {
    var map: [LegacyShortcutActionTest: Shortcut]
}

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

    @Test("Paste selection resolver uses the selected item and falls back to the first visible item")
    func pasteSelectionResolverUsesSelectedItem() {
        let alpha = makeTextItem("ALPHA-UNIQUE-1")
        let beta = makeTextItem("BETA-UNIQUE-2")
        let gamma = makeTextItem("GAMMA-UNIQUE-3")
        let items = [alpha, beta, gamma]

        #expect(PasteSelectionResolver.resolve(from: items, selectedItemID: beta.id)?.id == beta.id)
        #expect(PasteSelectionResolver.resolve(from: items, selectedItemID: UUID())?.id == alpha.id)
        #expect(PasteSelectionResolver.resolve(from: items, selectedItemID: nil)?.id == alpha.id)
    }

    @MainActor
    @Test("Paste back coordinator closes Edison, waits for target focus, then pastes")
    func pasteBackCoordinatorRunsOrderedPasteFlow() {
        let targetApp = NSRunningApplication.current
        let item = makeTextItem("BETA-UNIQUE-2")
        let expectedPID = targetApp.processIdentifier
        var events: [String] = []
        var scheduledActions: [@MainActor () -> Void] = []
        var isReadyForPaste = false

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { pastedItem in
                events.append("clipboard:\(pastedItem.id == item.id)")
                return true
            },
            isAccessibilityTrusted: {
                events.append("trusted")
                return true
            },
            activateTargetApp: { app in
                events.append("restore:\(app.processIdentifier)")
            },
            isTargetAppReady: { _ in
                events.append("ready:\(isReadyForPaste)")
                return isReadyForPaste
            },
            scheduleDelay: { _, action in
                events.append("delay")
                scheduledActions.append(action)
            },
            dispatchPaste: { pid in
                events.append("paste:\(pid)")
            },
            closeHub: {
                events.append("close")
            }
        )

        coordinator.run(item: item, targetApp: targetApp, completion: {
            events.append("complete")
        })

        #expect(events == [
            "clipboard:true",
            "trusted",
            "close",
            "restore:\(expectedPID)",
            "delay"
        ])
        #expect(scheduledActions.count == 1)

        scheduledActions.removeFirst()()

        #expect(events == [
            "clipboard:true",
            "trusted",
            "close",
            "restore:\(expectedPID)",
            "delay",
            "ready:false",
            "restore:\(expectedPID)",
            "delay"
        ])
        #expect(scheduledActions.count == 1)

        isReadyForPaste = true
        scheduledActions.removeFirst()()

        #expect(events == [
            "clipboard:true",
            "trusted",
            "close",
            "restore:\(expectedPID)",
            "delay",
            "ready:false",
            "restore:\(expectedPID)",
            "delay",
            "ready:true",
            "paste:\(expectedPID)",
            "complete"
        ])
    }

    @MainActor
    @Test("Paste back coordinator skips restore and paste when accessibility is unavailable")
    func pasteBackCoordinatorSkipsRestoreWithoutAccessibility() {
        let item = makeTextItem("BETA-UNIQUE-2")
        var events: [String] = []

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _ in
                events.append("clipboard")
                return true
            },
            isAccessibilityTrusted: {
                events.append("trusted:false")
                return false
            },
            activateTargetApp: { _ in
                events.append("restore")
            },
            scheduleDelay: { _, _ in
                events.append("delay")
            },
            dispatchPaste: { _ in
                events.append("paste")
            },
            closeHub: {
                events.append("close")
            }
        )

        coordinator.run(
            item: item,
            targetApp: NSRunningApplication.current,
            onAccessibilityDenied: {
                events.append("denied")
            },
            completion: {
                events.append("complete")
            }
        )

        #expect(events == [
            "clipboard",
            "trusted:false",
            "denied",
            "complete"
        ])
    }

    @MainActor
    @Test("Paste selection uses the selected item and blocks duplicate triggers until completion")
    func pasteSelectionUsesSelectedItemAndBlocksDuplicates() {
        let alpha = makeTextItem("ALPHA-UNIQUE-1")
        let beta = makeTextItem("BETA-UNIQUE-2")
        let gamma = makeTextItem("GAMMA-UNIQUE-3")
        let items = [alpha, beta, gamma]
        var startedItemIDs: [UUID] = []
        var scheduledAction: (@MainActor () -> Void)?

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { item in
                startedItemIDs.append(item.id)
                return true
            },
            isAccessibilityTrusted: { true },
            activateTargetApp: { _ in },
            isTargetAppReady: { _ in true },
            scheduleDelay: { _, action in
                scheduledAction = action
            },
            dispatchPaste: { _ in },
            closeHub: {}
        )
        let appState = AppState(
            enableRuntimeServices: false,
            pasteBackCoordinatorOverride: coordinator,
            initialLastActiveApp: NSRunningApplication.current
        )

        appState.pasteSelection(from: items, selectedItemID: beta.id)

        #expect(startedItemIDs == [beta.id])
        #expect(appState.isPasteInFlight)
        #expect(scheduledAction != nil)

        appState.pasteSelection(from: items, selectedItemID: gamma.id)
        #expect(startedItemIDs == [beta.id])

        scheduledAction?()

        #expect(!appState.isPasteInFlight)

        appState.pasteSelection(from: items, selectedItemID: gamma.id)
        #expect(startedItemIDs == [beta.id, gamma.id])
    }

    @MainActor
    @Test("Paste selection shows accessibility denial until the user requests access")
    func pasteSelectionDefersAccessibilityRequestUntilUserConfirms() {
        let item = makeTextItem("BETA-UNIQUE-2")
        var promptRequests = 0
        var settingsOpenRequests = 0

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _ in true },
            isAccessibilityTrusted: { false },
            activateTargetApp: { _ in },
            scheduleDelay: { _, _ in },
            dispatchPaste: { _ in },
            closeHub: {}
        )
        let appState = AppState(
            enableRuntimeServices: false,
            pasteBackCoordinatorOverride: coordinator,
            accessibilityPromptRequester: {
                promptRequests += 1
            },
            accessibilitySettingsOpener: {
                settingsOpenRequests += 1
            }
        )

        appState.pasteSelection(from: [item], selectedItemID: item.id)
        appState.pasteSelection(from: [item], selectedItemID: item.id)

        #expect(appState.accessibilityDenied)
        #expect(promptRequests == 0)
        #expect(settingsOpenRequests == 0)
        #expect(!appState.isPasteInFlight)

        appState.requestAccessibilityAccess()

        #expect(promptRequests == 1)
        #expect(settingsOpenRequests == 1)
    }

    @Test("Filename template expands date and time tokens")
    func filenameTemplateExpandsTokens() {
        var settings = AppSettings.default
        settings.capture.filenameTemplate = "Capture {date} {time}"

        let name = settings.defaultFileName(at: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(name.contains("Capture"))
        #expect(name.contains("2023"))
    }

    @Test("Shortcut store migrates legacy capture area binding to capture screenshot")
    func shortcutStoreMigratesLegacyBindings() {
        let suiteName = "EdisonTests.Shortcuts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacy = LegacyShortcutSetTest(map: [
            .openHub: .defaultOpenHub,
            .captureArea: .commandShift(kVK_ANSI_2),
            .captureWindow: .commandShift(kVK_ANSI_3),
            .captureFullScreen: .commandShift(kVK_ANSI_4)
        ])

        defaults.set(try! JSONEncoder().encode(legacy), forKey: "edison.shortcuts.v1")

        let store = ShortcutStore(defaults: defaults)
        let shortcuts = store.current

        #expect(shortcuts[.captureScreenshot] == Shortcut.commandShift(kVK_ANSI_2))
        #expect(shortcuts[.captureWindow] == Shortcut.commandShift(kVK_ANSI_3))
        #expect(defaults.data(forKey: "edison.shortcuts.v2") != nil)
    }

    @Test("Shortcut validator catches duplicates and reserved shortcuts")
    func shortcutValidatorReportsConflicts() {
        let duplicate = Shortcut.defaultOpenHub
        let shortcuts = ShortcutSet(map: [
            .openHub: duplicate,
            .captureScreenshot: duplicate,
            .openSettings: Shortcut(keyCode: UInt32(kVK_ANSI_Comma), modifiers: UInt32(cmdKey))
        ])

        let issues = ShortcutValidator.validationIssues(for: shortcuts)

        #expect(issues[ShortcutAction.captureScreenshot]?.contains(ShortcutValidationIssue.duplicate(with: .openHub)) == true)
        #expect(issues[ShortcutAction.openSettings]?.contains(ShortcutValidationIssue.reservedShortcut) == true)
    }

    @MainActor
    @Test("Screenshot session undo and redo preserve annotation history")
    func screenshotSessionUndoRedo() {
        let draft = ScreenshotDraft(
            baseImageData: makeTestImageData(),
            fileNameHint: "Test"
        )
        let session = ScreenshotSession(draft: draft)
        var snapshot = session.currentSnapshot
        snapshot.annotations.append(.rectangle(CGRect(x: 10, y: 10, width: 20, height: 12), style: .default))
        session.commit(snapshot: snapshot)

        #expect(session.currentSnapshot.annotations.count == 1)
        #expect(session.canUndo)

        session.undo()
        #expect(session.currentSnapshot.annotations.isEmpty)
        #expect(session.canRedo)

        session.redo()
        #expect(session.currentSnapshot.annotations.count == 1)
    }

    @MainActor
    @Test("Screenshot session records commit state")
    func screenshotSessionCommitState() {
        let draft = ScreenshotDraft(
            baseImageData: makeTestImageData(),
            fileNameHint: "Test"
        )
        let session = ScreenshotSession(draft: draft)

        #expect(session.hasUnsavedChanges)

        session.recordCommit(itemID: UUID())

        #expect(!session.hasUnsavedChanges)
    }
}
#elseif canImport(XCTest)
import XCTest
import Carbon
@testable import Edison

private func makeTextItem(_ value: String) -> ClipboardItem {
    ClipboardItem(payload: .text(value))
}

private func makeTestImageData(size: NSSize = NSSize(width: 80, height: 60)) -> Data {
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
    image.unlockFocus()

    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

private enum LegacyShortcutActionTest: String, Codable, Hashable {
    case openHub
    case captureArea
    case captureWindow
    case captureFullScreen
}

private struct LegacyShortcutSetTest: Codable, Hashable {
    var map: [LegacyShortcutActionTest: Shortcut]
}

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

    func testPasteSelectionResolverUsesSelectedItem() {
        let alpha = makeTextItem("ALPHA-UNIQUE-1")
        let beta = makeTextItem("BETA-UNIQUE-2")
        let gamma = makeTextItem("GAMMA-UNIQUE-3")
        let items = [alpha, beta, gamma]

        XCTAssertEqual(PasteSelectionResolver.resolve(from: items, selectedItemID: beta.id)?.id, beta.id)
        XCTAssertEqual(PasteSelectionResolver.resolve(from: items, selectedItemID: UUID())?.id, alpha.id)
        XCTAssertEqual(PasteSelectionResolver.resolve(from: items, selectedItemID: nil)?.id, alpha.id)
    }

    @MainActor
    func testPasteBackCoordinatorRunsOrderedPasteFlow() {
        let targetApp = NSRunningApplication.current
        let item = makeTextItem("BETA-UNIQUE-2")
        let expectedPID = targetApp.processIdentifier
        var events: [String] = []
        var scheduledActions: [@MainActor () -> Void] = []
        var isReadyForPaste = false

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { pastedItem in
                events.append("clipboard:\(pastedItem.id == item.id)")
                return true
            },
            isAccessibilityTrusted: {
                events.append("trusted")
                return true
            },
            activateTargetApp: { app in
                events.append("restore:\(app.processIdentifier)")
            },
            isTargetAppReady: { _ in
                events.append("ready:\(isReadyForPaste)")
                return isReadyForPaste
            },
            scheduleDelay: { _, action in
                events.append("delay")
                scheduledActions.append(action)
            },
            dispatchPaste: { pid in
                events.append("paste:\(pid)")
            },
            closeHub: {
                events.append("close")
            }
        )

        coordinator.run(item: item, targetApp: targetApp, completion: {
            events.append("complete")
        })

        XCTAssertEqual(events, [
            "clipboard:true",
            "trusted",
            "close",
            "restore:\(expectedPID)",
            "delay"
        ])
        XCTAssertEqual(scheduledActions.count, 1)

        scheduledActions.removeFirst()()

        XCTAssertEqual(events, [
            "clipboard:true",
            "trusted",
            "close",
            "restore:\(expectedPID)",
            "delay",
            "ready:false",
            "restore:\(expectedPID)",
            "delay"
        ])
        XCTAssertEqual(scheduledActions.count, 1)

        isReadyForPaste = true
        scheduledActions.removeFirst()()

        XCTAssertEqual(events, [
            "clipboard:true",
            "trusted",
            "close",
            "restore:\(expectedPID)",
            "delay",
            "ready:false",
            "restore:\(expectedPID)",
            "delay",
            "ready:true",
            "paste:\(expectedPID)",
            "complete"
        ])
    }

    @MainActor
    func testPasteBackCoordinatorSkipsRestoreWithoutAccessibility() {
        let item = makeTextItem("BETA-UNIQUE-2")
        var events: [String] = []

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _ in
                events.append("clipboard")
                return true
            },
            isAccessibilityTrusted: {
                events.append("trusted:false")
                return false
            },
            activateTargetApp: { _ in
                events.append("restore")
            },
            scheduleDelay: { _, _ in
                events.append("delay")
            },
            dispatchPaste: { _ in
                events.append("paste")
            },
            closeHub: {
                events.append("close")
            }
        )

        coordinator.run(
            item: item,
            targetApp: NSRunningApplication.current,
            onAccessibilityDenied: {
                events.append("denied")
            },
            completion: {
                events.append("complete")
            }
        )

        XCTAssertEqual(events, [
            "clipboard",
            "trusted:false",
            "denied",
            "complete"
        ])
    }

    @MainActor
    func testPasteSelectionUsesSelectedItemAndBlocksDuplicates() {
        let alpha = makeTextItem("ALPHA-UNIQUE-1")
        let beta = makeTextItem("BETA-UNIQUE-2")
        let gamma = makeTextItem("GAMMA-UNIQUE-3")
        let items = [alpha, beta, gamma]
        var startedItemIDs: [UUID] = []
        var scheduledAction: (@MainActor () -> Void)?

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { item in
                startedItemIDs.append(item.id)
                return true
            },
            isAccessibilityTrusted: { true },
            activateTargetApp: { _ in },
            isTargetAppReady: { _ in true },
            scheduleDelay: { _, action in
                scheduledAction = action
            },
            dispatchPaste: { _ in },
            closeHub: {}
        )
        let appState = AppState(
            enableRuntimeServices: false,
            pasteBackCoordinatorOverride: coordinator,
            initialLastActiveApp: NSRunningApplication.current
        )

        appState.pasteSelection(from: items, selectedItemID: beta.id)

        XCTAssertEqual(startedItemIDs, [beta.id])
        XCTAssertTrue(appState.isPasteInFlight)
        XCTAssertNotNil(scheduledAction)

        appState.pasteSelection(from: items, selectedItemID: gamma.id)
        XCTAssertEqual(startedItemIDs, [beta.id])

        scheduledAction?()

        XCTAssertFalse(appState.isPasteInFlight)

        appState.pasteSelection(from: items, selectedItemID: gamma.id)
        XCTAssertEqual(startedItemIDs, [beta.id, gamma.id])
    }

    @MainActor
    func testPasteSelectionDefersAccessibilityRequestUntilUserConfirms() {
        let item = makeTextItem("BETA-UNIQUE-2")
        var promptRequests = 0
        var settingsOpenRequests = 0

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _ in true },
            isAccessibilityTrusted: { false },
            activateTargetApp: { _ in },
            scheduleDelay: { _, _ in },
            dispatchPaste: { _ in },
            closeHub: {}
        )
        let appState = AppState(
            enableRuntimeServices: false,
            pasteBackCoordinatorOverride: coordinator,
            accessibilityPromptRequester: {
                promptRequests += 1
            },
            accessibilitySettingsOpener: {
                settingsOpenRequests += 1
            }
        )

        appState.pasteSelection(from: [item], selectedItemID: item.id)
        appState.pasteSelection(from: [item], selectedItemID: item.id)

        XCTAssertTrue(appState.accessibilityDenied)
        XCTAssertEqual(promptRequests, 0)
        XCTAssertEqual(settingsOpenRequests, 0)
        XCTAssertFalse(appState.isPasteInFlight)

        appState.requestAccessibilityAccess()

        XCTAssertEqual(promptRequests, 1)
        XCTAssertEqual(settingsOpenRequests, 1)
    }

    func testFilenameTemplateExpandsTokens() {
        var settings = AppSettings.default
        settings.capture.filenameTemplate = "Capture {date} {time}"

        let name = settings.defaultFileName(at: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertTrue(name.contains("Capture"))
        XCTAssertTrue(name.contains("2023"))
    }

    func testShortcutStoreMigratesLegacyBindings() {
        let suiteName = "EdisonTests.Shortcuts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacy = LegacyShortcutSetTest(map: [
            .openHub: .defaultOpenHub,
            .captureArea: .commandShift(kVK_ANSI_2),
            .captureWindow: .commandShift(kVK_ANSI_3),
            .captureFullScreen: .commandShift(kVK_ANSI_4)
        ])
        defaults.set(try! JSONEncoder().encode(legacy), forKey: "edison.shortcuts.v1")

        let store = ShortcutStore(defaults: defaults)
        let shortcuts = store.current

        XCTAssertEqual(shortcuts[.captureScreenshot], Shortcut.commandShift(kVK_ANSI_2))
        XCTAssertEqual(shortcuts[.captureWindow], Shortcut.commandShift(kVK_ANSI_3))
        XCTAssertNotNil(defaults.data(forKey: "edison.shortcuts.v2"))
    }

    func testShortcutValidatorReportsConflicts() {
        let duplicate = Shortcut.defaultOpenHub
        let shortcuts = ShortcutSet(map: [
            .openHub: duplicate,
            .captureScreenshot: duplicate,
            .openSettings: Shortcut(keyCode: UInt32(kVK_ANSI_Comma), modifiers: UInt32(cmdKey))
        ])

        let issues = ShortcutValidator.validationIssues(for: shortcuts)

        XCTAssertTrue(issues[ShortcutAction.captureScreenshot]?.contains(ShortcutValidationIssue.duplicate(with: .openHub)) == true)
        XCTAssertTrue(issues[ShortcutAction.openSettings]?.contains(ShortcutValidationIssue.reservedShortcut) == true)
    }

    @MainActor
    func testScreenshotSessionUndoRedo() {
        let draft = ScreenshotDraft(
            baseImageData: makeTestImageData(),
            fileNameHint: "Test"
        )
        let session = ScreenshotSession(draft: draft)
        var snapshot = session.currentSnapshot
        snapshot.annotations.append(.rectangle(CGRect(x: 10, y: 10, width: 20, height: 12), style: .default))
        session.commit(snapshot: snapshot)

        XCTAssertEqual(session.currentSnapshot.annotations.count, 1)
        XCTAssertTrue(session.canUndo)

        session.undo()
        XCTAssertTrue(session.currentSnapshot.annotations.isEmpty)
        XCTAssertTrue(session.canRedo)

        session.redo()
        XCTAssertEqual(session.currentSnapshot.annotations.count, 1)
    }

    @MainActor
    func testScreenshotSessionCommitState() {
        let draft = ScreenshotDraft(
            baseImageData: makeTestImageData(),
            fileNameHint: "Test"
        )
        let session = ScreenshotSession(draft: draft)

        XCTAssertTrue(session.hasUnsavedChanges)
        session.recordCommit(itemID: UUID())
        XCTAssertFalse(session.hasUnsavedChanges)
    }
}
#endif
