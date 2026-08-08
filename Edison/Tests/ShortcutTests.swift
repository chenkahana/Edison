import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if canImport(Testing)
import Testing
import Carbon
@testable import Edison

struct ShortcutTests {
    @Test("Shortcut store migrates legacy capture area binding to capture screenshot")
    func shortcutStoreMigratesLegacyBindings() {
        let (suiteName, defaults) = makeTestDefaults(label: "Shortcuts.Migration")
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
}
#elseif canImport(XCTest)
import XCTest
import Carbon
@testable import Edison

final class ShortcutTests: XCTestCase {
    func testShortcutStoreMigratesLegacyBindings() {
        let (suiteName, defaults) = makeTestDefaults(label: "Shortcuts.Migration")
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
}
#endif
