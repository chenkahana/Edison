import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if canImport(Testing)
import Testing
@testable import Edison

struct CaptureTests {
    @Test("Filename template expands date and time tokens")
    func filenameTemplateExpandsTokens() {
        var settings = AppSettings.default
        settings.capture.filenameTemplate = "Capture {date} {time}"

        let name = settings.defaultFileName(at: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(name.contains("Capture"))
        #expect(name.contains("2023"))
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
@testable import Edison

final class CaptureTests: XCTestCase {
    func testFilenameTemplateExpandsTokens() {
        var settings = AppSettings.default
        settings.capture.filenameTemplate = "Capture {date} {time}"

        let name = settings.defaultFileName(at: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertTrue(name.contains("Capture"))
        XCTAssertTrue(name.contains("2023"))
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
