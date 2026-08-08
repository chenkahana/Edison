import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if canImport(Testing)
import Testing
@testable import Edison

// MARK: - WindowRouterTests
//
// Tests cover the four lifecycle invariants identified in the W5.3 audit:
//  1. toggleHub opens hub when no window is registered
//  2. toggleHub closes hub when hub window is already visible
//  3. dismissHub clears hubRequestedVisible (isHubPresented -> false)
//  4. openEditor / closeEditor (dismissEditor) lifecycle preserves state invariants
//
// WindowRouter is @MainActor and interacts with NSApp.windows; tests run on the
// main actor and use a real WindowRouter with stubbed openHub/openEditor actions
// to avoid actually creating NSWindows.

struct WindowRouterTests {

    // MARK: - Helpers

    /// Returns a WindowRouter with no-op open actions so toggleHub/openHub/openEditor
    /// do not attempt to open a real SwiftUI scene.
    ///
    /// Also ensures NSApplication.shared is initialized, which is required because
    /// WindowRouter reads NSApp.windows and NSApp is an IUO that is nil in SPM test
    /// bundles until the shared application is first accessed.
    @MainActor
    private func makeRouter() -> WindowRouter {
        _ = NSApplication.shared   // ensure NSApp != nil before accessing NSApp.windows
        let router = WindowRouter()
        router.setOpenHubAction { /* no-op: no SwiftUI scene in tests */ }
        router.setOpenEditorAction { /* no-op */ }
        return router
    }

    // MARK: - Test 1: toggleHub opens hub when no window exists

    /// When no hub window is registered and hubRequestedVisible is false,
    /// toggleHub should set hubRequestedVisible (isHubPresented == true).
    @MainActor
    @Test("toggleHub sets hubRequestedVisible when hub is not presented")
    func toggleHubOpensHubWhenNotPresented() {
        let router = makeRouter()

        // Precondition: hub not presented.
        #expect(!router.isHubPresented,
                "isHubPresented must start false with no registered window")

        router.toggleHub()

        // toggleHub -> openHub -> hubRequestedVisible = true.
        // Even though no real NSWindow was created (open action is a no-op),
        // the requested-visible flag must be set so that when the window does
        // arrive via registerHubWindow it is shown automatically.
        #expect(router.isHubPresented,
                "isHubPresented must be true after toggleHub on a closed hub")
    }

    // MARK: - Test 2: toggleHub closes hub when window exists

    /// When hubRequestedVisible is true (hub was opened), a second toggleHub
    /// should call dismissHub, setting hubRequestedVisible back to false.
    @MainActor
    @Test("toggleHub dismisses hub when hub is already presented")
    func toggleHubDismissesHubWhenAlreadyPresented() {
        let router = makeRouter()

        // Open the hub first.
        router.toggleHub()
        #expect(router.isHubPresented,
                "isHubPresented must be true after first toggleHub")

        // Toggle again — should dismiss.
        router.toggleHub()

        #expect(!router.isHubPresented,
                "isHubPresented must be false after second toggleHub (dismiss)")
    }

    // MARK: - Test 3: dismissHub clears internal state

    /// dismissHub must set hubRequestedVisible to false and leave isHubPresented false
    /// regardless of whether a real NSWindow was involved.
    @MainActor
    @Test("dismissHub clears hubRequestedVisible flag")
    func dismissHubClearsInternalState() {
        let router = makeRouter()

        // Drive hubRequestedVisible to true.
        router.openHub()
        #expect(router.isHubPresented,
                "isHubPresented must be true after openHub")

        router.dismissHub()

        #expect(!router.isHubPresented,
                "isHubPresented must be false after dismissHub")
    }

    // MARK: - Test 4: openEditor / dismissEditor lifecycle preserves invariants

    /// After openEditor the router has attempted to open the editor window.
    /// After dismissEditor (with no real window) the router falls back gracefully
    /// (resolveEditorWindow returns nil, orderOut is a no-op). Neither call should crash.
    /// The hub state must be unaffected by editor open/close.
    @MainActor
    @Test("openEditor and dismissEditor do not affect hub state")
    func openEditorAndDismissEditorPreservesHubState() {
        let router = makeRouter()

        // Open hub first to give hub a non-trivial state.
        router.openHub()
        #expect(router.isHubPresented, "hub must be presented before editor test")

        // Open editor (no-op action, no real window created).
        router.openEditor()

        // Hub state must be unchanged.
        #expect(router.isHubPresented,
                "opening the editor must not affect hub presented state")

        // Dismiss editor — resolveEditorWindow returns nil (no window registered),
        // so orderOut is never called. Must not crash.
        router.dismissEditor()

        // Hub state still unchanged.
        #expect(router.isHubPresented,
                "dismissing the editor must not affect hub presented state")

        // Now dismiss hub to verify full round-trip.
        router.dismissHub()
        #expect(!router.isHubPresented,
                "hub must be dismissed after explicit dismissHub call")
    }
}

#endif
