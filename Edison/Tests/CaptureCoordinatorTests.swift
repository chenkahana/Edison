import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if canImport(Testing)
import Testing
@testable import Edison

struct CaptureCoordinatorTests {

    // MARK: - Helpers

    @MainActor
    private func makeCoordinator(
        addToHistory: @escaping (ClipboardItem) -> Void = { _ in },
        suppressClipboardPayload: @escaping (ClipboardPayload) -> Void = { _ in }
    ) -> CaptureCoordinator {
        CaptureCoordinator(
            captureEngine: CaptureEngine(),
            windowRouter: nil,
            addToHistory: addToHistory,
            suppressClipboardPayload: suppressClipboardPayload,
            historyItems: { [] },
            setHistoryItems: { _ in },
            promoteItemToFront: { _ in },
            currentSettings: { .default },
            closeEditor: {},
            presentError: { _, _ in }
        )
    }

    // MARK: - W4b.2 Test 1: handleCaptureResult success path

    /// Verifies that a successful CaptureResult stores the session, clears captureError,
    /// and does NOT open the editor when defaultResult == .keepInHistory and
    /// openEditorAfterCapture == false (the non-editor path calls commitScreenshotSession,
    /// which calls addToHistory).
    @MainActor
    @Test("handleCaptureResult success stores session and clears error")
    func handleCaptureResultSuccessStoresSessionAndClearsError() async {
        var historyReceived: [ClipboardItem] = []

        let coordinator = CaptureCoordinator(
            captureEngine: CaptureEngine(),
            windowRouter: nil,
            addToHistory: { item in
                historyReceived.append(item)
            },
            suppressClipboardPayload: { _ in },
            historyItems: { historyReceived },
            setHistoryItems: { historyReceived = $0 },
            promoteItemToFront: { _ in },
            currentSettings: {
                var s = AppSettings.default
                s.capture.openEditorAfterCapture = false
                s.capture.defaultResult = .keepInHistory
                s.editor.closeAfterCopySave = false
                return s
            },
            closeEditor: {},
            presentError: { _, _ in }
        )

        // Seed captureError to confirm it is cleared.
        coordinator.captureError = "previous error"

        let imageData = makeTestImageData()
        await coordinator.handleCaptureResult(.success(data: imageData, displayID: nil, rect: nil))

        #expect(coordinator.captureError == nil,
                "captureError must be cleared on a successful capture result")
        #expect(coordinator.lastCaptureFailureReason == nil,
                "lastCaptureFailureReason must be cleared on success")
        // The non-editor path calls commitScreenshotSession → persistScreenshotImage → addToHistory.
        #expect(!historyReceived.isEmpty,
                "A successful capture without editor must add an item to history")
    }

    // MARK: - W4b.2 Test 2: handleCaptureResult failure path

    /// Verifies that a failed CaptureResult sets captureError and lastCaptureFailureReason.
    @MainActor
    @Test("handleCaptureResult failure sets captureError and lastCaptureFailureReason")
    func handleCaptureResultFailureSetsError() async {
        let coordinator = makeCoordinator()

        let reason = "Unit-test-failure-reason-\(UUID().uuidString)"
        await coordinator.handleCaptureResult(.failure(reason))

        #expect(coordinator.captureError == reason,
                "captureError must be set to the failure reason")
        #expect(coordinator.lastCaptureFailureReason == reason,
                "lastCaptureFailureReason must be set to the failure reason")
        #expect(coordinator.activeScreenshotSession == nil,
                "activeScreenshotSession must remain nil on failure")
    }

    // MARK: - W4b.2 Test 3: commitScreenshotSession calls addToHistory and suppressClipboardPayload

    /// Verifies that commitScreenshotSession with copyToClipboard: true
    /// invokes both addToHistory (via persistScreenshotImage) and
    /// suppressClipboardPayload (via writeImageDataToClipboard), and that
    /// addToHistory is called before suppressClipboardPayload.
    @MainActor
    @Test("commitScreenshotSession calls addToHistory then suppressClipboardPayload when copyToClipboard is true")
    func commitScreenshotSessionCallsAddToHistoryAndSuppressPayload() {
        var events: [String] = []
        var storedItems: [ClipboardItem] = []

        let coordinator = CaptureCoordinator(
            captureEngine: CaptureEngine(),
            windowRouter: nil,
            addToHistory: { item in
                events.append("addToHistory")
                storedItems.append(item)
            },
            suppressClipboardPayload: { _ in
                events.append("suppress")
            },
            historyItems: { storedItems },
            setHistoryItems: { storedItems = $0 },
            promoteItemToFront: { _ in },
            currentSettings: {
                var s = AppSettings.default
                s.editor.closeAfterCopySave = false
                return s
            },
            closeEditor: {},
            presentError: { _, _ in }
        )

        let draft = ScreenshotDraft(
            baseImageData: makeTestImageData(),
            fileNameHint: "TestCommit"
        )
        let session = ScreenshotSession(draft: draft)

        coordinator.commitScreenshotSession(session, copyToClipboard: true)

        #expect(events.contains("addToHistory"),
                "addToHistory must be called during commitScreenshotSession")
        #expect(events.contains("suppress"),
                "suppressClipboardPayload must be called when copyToClipboard is true")

        // addToHistory (inside persistScreenshotImage) happens before
        // suppressClipboardPayload (inside writeImageDataToClipboard).
        let addIdx = events.firstIndex(of: "addToHistory")
        let suppressIdx = events.firstIndex(of: "suppress")
        if let a = addIdx, let s = suppressIdx {
            #expect(a < s, "addToHistory must be called before suppressClipboardPayload")
        }
    }
}

#elseif canImport(XCTest)
import XCTest
@testable import Edison

final class CaptureCoordinatorTests: XCTestCase {

    // MARK: - Helpers

    @MainActor
    private func makeCoordinator(
        addToHistory: @escaping (ClipboardItem) -> Void = { _ in },
        suppressClipboardPayload: @escaping (ClipboardPayload) -> Void = { _ in }
    ) -> CaptureCoordinator {
        CaptureCoordinator(
            captureEngine: CaptureEngine(),
            windowRouter: nil,
            addToHistory: addToHistory,
            suppressClipboardPayload: suppressClipboardPayload,
            historyItems: { [] },
            setHistoryItems: { _ in },
            promoteItemToFront: { _ in },
            currentSettings: { .default },
            closeEditor: {},
            presentError: { _, _ in }
        )
    }

    // MARK: - W4b.2 Test 1: handleCaptureResult success path

    @MainActor
    func testHandleCaptureResultSuccessStoresSessionAndClearsError() async {
        var historyReceived: [ClipboardItem] = []

        let coordinator = CaptureCoordinator(
            captureEngine: CaptureEngine(),
            windowRouter: nil,
            addToHistory: { item in
                historyReceived.append(item)
            },
            suppressClipboardPayload: { _ in },
            historyItems: { historyReceived },
            setHistoryItems: { historyReceived = $0 },
            promoteItemToFront: { _ in },
            currentSettings: {
                var s = AppSettings.default
                s.capture.openEditorAfterCapture = false
                s.capture.defaultResult = .keepInHistory
                s.editor.closeAfterCopySave = false
                return s
            },
            closeEditor: {},
            presentError: { _, _ in }
        )

        coordinator.captureError = "previous error"

        let imageData = makeTestImageData()
        await coordinator.handleCaptureResult(.success(data: imageData, displayID: nil, rect: nil))

        XCTAssertNil(coordinator.captureError,
                     "captureError must be cleared on a successful capture result")
        XCTAssertNil(coordinator.lastCaptureFailureReason,
                     "lastCaptureFailureReason must be cleared on success")
        XCTAssertFalse(historyReceived.isEmpty,
                       "A successful capture without editor must add an item to history")
    }

    // MARK: - W4b.2 Test 2: handleCaptureResult failure path

    @MainActor
    func testHandleCaptureResultFailureSetsError() async {
        let coordinator = makeCoordinator()

        let reason = "Unit-test-failure-reason-\(UUID().uuidString)"
        await coordinator.handleCaptureResult(.failure(reason))

        XCTAssertEqual(coordinator.captureError, reason,
                       "captureError must be set to the failure reason")
        XCTAssertEqual(coordinator.lastCaptureFailureReason, reason,
                       "lastCaptureFailureReason must be set to the failure reason")
        XCTAssertNil(coordinator.activeScreenshotSession,
                     "activeScreenshotSession must remain nil on failure")
    }

    // MARK: - W4b.2 Test 3: commitScreenshotSession calls addToHistory and suppressClipboardPayload

    @MainActor
    func testCommitScreenshotSessionCallsAddToHistoryAndSuppressPayload() {
        var events: [String] = []
        var storedItems: [ClipboardItem] = []

        let coordinator = CaptureCoordinator(
            captureEngine: CaptureEngine(),
            windowRouter: nil,
            addToHistory: { item in
                events.append("addToHistory")
                storedItems.append(item)
            },
            suppressClipboardPayload: { _ in
                events.append("suppress")
            },
            historyItems: { storedItems },
            setHistoryItems: { storedItems = $0 },
            promoteItemToFront: { _ in },
            currentSettings: {
                var s = AppSettings.default
                s.editor.closeAfterCopySave = false
                return s
            },
            closeEditor: {},
            presentError: { _, _ in }
        )

        let draft = ScreenshotDraft(
            baseImageData: makeTestImageData(),
            fileNameHint: "TestCommit"
        )
        let session = ScreenshotSession(draft: draft)

        coordinator.commitScreenshotSession(session, copyToClipboard: true)

        XCTAssertTrue(events.contains("addToHistory"),
                      "addToHistory must be called during commitScreenshotSession")
        XCTAssertTrue(events.contains("suppress"),
                      "suppressClipboardPayload must be called when copyToClipboard is true")

        let addIdx = events.firstIndex(of: "addToHistory")
        let suppressIdx = events.firstIndex(of: "suppress")
        if let a = addIdx, let s = suppressIdx {
            XCTAssertLessThan(a, s, "addToHistory must be called before suppressClipboardPayload")
        }
    }
}
#endif
