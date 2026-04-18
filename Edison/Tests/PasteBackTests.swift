import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if canImport(Testing)
import Testing
@testable import Edison

struct PasteBackTests {

    // MARK: - Existing tests (migrated from EdisonTests.swift)

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

    // MARK: - W4a.2: New PasteBackCoordinator timing tests

    /// Test 1: Successful paste-back completes in the expected ordered sequence.
    /// Uses synchronous fake scheduler — no real clock needed, so no timing tolerance required.
    /// The coordinator calls clipboard-write, accessibility-check, close-hub, activate-app,
    /// then once ready: dispatch-paste and complete.
    @MainActor
    @Test("Successful paste-back completes with ordered clipboard-activate-paste sequence",
          .timeLimit(.minutes(1)))
    func pasteBackSuccessfulFlowCompletesInOrder() {
        let item = makeTextItem("TIMING-TEST-1")
        let targetApp = NSRunningApplication.current
        let pid = targetApp.processIdentifier
        var events: [String] = []
        var pendingAction: (@MainActor () -> Void)?

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _ in
                events.append("write")
                return true
            },
            isAccessibilityTrusted: {
                events.append("access-check")
                return true
            },
            activateTargetApp: { _ in
                events.append("activate")
            },
            isTargetAppReady: { _ in true },
            scheduleDelay: { _, action in
                events.append("schedule")
                pendingAction = action
            },
            dispatchPaste: { _ in
                events.append("paste")
            },
            closeHub: {
                events.append("close")
            }
        )

        var completed = false
        coordinator.run(item: item, targetApp: targetApp, completion: {
            completed = true
            events.append("done")
        })

        // Before the scheduled delay fires: clipboard write, access check, close, activate all happen synchronously.
        #expect(events == ["write", "access-check", "close", "activate", "schedule"])
        #expect(!completed)

        // Fire the scheduled action — app is already ready, so paste dispatches immediately.
        pendingAction?()

        #expect(events == ["write", "access-check", "close", "activate", "schedule", "paste", "done"])
        #expect(completed)
        _ = pid // suppress unused-variable warning; pid is implicit in the test scenario
    }

    /// Test 2: Accessibility denied — coordinator must NOT dispatch Cmd+V,
    /// must invoke the denial callback, and must clear in-flight state (completion fires).
    @MainActor
    @Test("Accessibility denied path skips paste and invokes denial callback",
          .timeLimit(.minutes(1)))
    func pasteBackAccessibilityDeniedSkipsPasteAndInvokesDenial() {
        let item = makeTextItem("TIMING-TEST-2")
        var pasteDispatched = false
        var denialFired = false
        var completionFired = false
        var delayScheduled = false

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _ in true },
            isAccessibilityTrusted: { false },   // simulate denied
            activateTargetApp: { _ in },
            scheduleDelay: { _, _ in
                delayScheduled = true
            },
            dispatchPaste: { _ in
                pasteDispatched = true
            },
            closeHub: {}
        )

        coordinator.run(
            item: item,
            targetApp: NSRunningApplication.current,
            onAccessibilityDenied: { denialFired = true },
            completion: { completionFired = true }
        )

        #expect(!pasteDispatched, "Cmd+V must NOT be dispatched when accessibility is denied")
        #expect(denialFired, "Denial callback must be invoked")
        #expect(completionFired, "Completion must fire to clear in-flight state")
        #expect(!delayScheduled, "No delay should be scheduled on the denied path")
    }

    /// Test 3: Nil target app — coordinator copies to clipboard and completes without
    /// attempting to activate any app. Verifies no crash, no hang, no activate call.
    @MainActor
    @Test("Nil target app fallback copies to clipboard and completes without activating any app",
          .timeLimit(.minutes(1)))
    func pasteBackNilTargetAppFallsBackToCopyOnly() {
        let item = makeTextItem("TIMING-TEST-3")
        var clipboardWritten = false
        var activateCalled = false
        var pasteDispatched = false
        var completionFired = false

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _ in
                clipboardWritten = true
                return true
            },
            isAccessibilityTrusted: { true },
            activateTargetApp: { _ in
                activateCalled = true
            },
            scheduleDelay: { _, action in
                // Should not be reached; call through anyway to avoid false positives.
                action()
            },
            dispatchPaste: { _ in
                pasteDispatched = true
            },
            closeHub: {}
        )

        coordinator.run(item: item, targetApp: nil, completion: {
            completionFired = true
        })

        #expect(clipboardWritten, "Clipboard must be written even when targetApp is nil")
        #expect(!activateCalled, "No app should be activated when targetApp is nil")
        #expect(!pasteDispatched, "No paste should be dispatched when targetApp is nil")
        #expect(completionFired, "Completion must fire to clear in-flight state")
    }
}
#elseif canImport(XCTest)
import XCTest
@testable import Edison

final class PasteBackTests: XCTestCase {

    // MARK: - Existing tests (migrated from EdisonTests.swift)

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

    // MARK: - W4a.2: New PasteBackCoordinator timing tests

    @MainActor
    func testPasteBackSuccessfulFlowCompletesInOrder() {
        let item = makeTextItem("TIMING-TEST-1")
        let targetApp = NSRunningApplication.current
        var events: [String] = []
        var pendingAction: (@MainActor () -> Void)?

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _ in
                events.append("write")
                return true
            },
            isAccessibilityTrusted: {
                events.append("access-check")
                return true
            },
            activateTargetApp: { _ in
                events.append("activate")
            },
            isTargetAppReady: { _ in true },
            scheduleDelay: { _, action in
                events.append("schedule")
                pendingAction = action
            },
            dispatchPaste: { _ in
                events.append("paste")
            },
            closeHub: {
                events.append("close")
            }
        )

        var completed = false
        coordinator.run(item: item, targetApp: targetApp, completion: {
            completed = true
            events.append("done")
        })

        XCTAssertEqual(events, ["write", "access-check", "close", "activate", "schedule"])
        XCTAssertFalse(completed)

        pendingAction?()

        XCTAssertEqual(events, ["write", "access-check", "close", "activate", "schedule", "paste", "done"])
        XCTAssertTrue(completed)
    }

    @MainActor
    func testPasteBackAccessibilityDeniedSkipsPasteAndInvokesDenial() {
        let item = makeTextItem("TIMING-TEST-2")
        var pasteDispatched = false
        var denialFired = false
        var completionFired = false
        var delayScheduled = false

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _ in true },
            isAccessibilityTrusted: { false },
            activateTargetApp: { _ in },
            scheduleDelay: { _, _ in
                delayScheduled = true
            },
            dispatchPaste: { _ in
                pasteDispatched = true
            },
            closeHub: {}
        )

        coordinator.run(
            item: item,
            targetApp: NSRunningApplication.current,
            onAccessibilityDenied: { denialFired = true },
            completion: { completionFired = true }
        )

        XCTAssertFalse(pasteDispatched, "Cmd+V must NOT be dispatched when accessibility is denied")
        XCTAssertTrue(denialFired, "Denial callback must be invoked")
        XCTAssertTrue(completionFired, "Completion must fire to clear in-flight state")
        XCTAssertFalse(delayScheduled, "No delay should be scheduled on the denied path")
    }

    @MainActor
    func testPasteBackNilTargetAppFallsBackToCopyOnly() {
        let item = makeTextItem("TIMING-TEST-3")
        var clipboardWritten = false
        var activateCalled = false
        var pasteDispatched = false
        var completionFired = false

        let coordinator = PasteBackCoordinator(
            writeItemToClipboard: { _ in
                clipboardWritten = true
                return true
            },
            isAccessibilityTrusted: { true },
            activateTargetApp: { _ in
                activateCalled = true
            },
            scheduleDelay: { _, action in
                action()
            },
            dispatchPaste: { _ in
                pasteDispatched = true
            },
            closeHub: {}
        )

        coordinator.run(item: item, targetApp: nil, completion: {
            completionFired = true
        })

        XCTAssertTrue(clipboardWritten, "Clipboard must be written even when targetApp is nil")
        XCTAssertFalse(activateCalled, "No app should be activated when targetApp is nil")
        XCTAssertFalse(pasteDispatched, "No paste should be dispatched when targetApp is nil")
        XCTAssertTrue(completionFired, "Completion must fire to clear in-flight state")
    }
}
#endif
