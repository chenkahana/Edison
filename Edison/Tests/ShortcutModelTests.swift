import Foundation

#if canImport(Testing)
import Testing
import AppKit
import Carbon
@testable import Edison

/// Shortcut defaults, validation rules and display. Key glyphs depend on the keyboard layout of the machine running
/// the tests, so display assertions only cover the modifier prefix.
struct ShortcutModelTests {
    @Test("The shipped defaults pass validation and don't collide with each other")
    func defaultsAreValid() {
        #expect(ShortcutValidator.validationIssues(for: .default).isEmpty)
        #expect(ShortcutValidator.validationIssues(for: .previousDefault).isEmpty)
        #expect(Shortcut.defaultOpenHub != Shortcut.defaultCaptureScreenshot)
        #expect(Shortcut.defaultOpenHub != Shortcut.previousDefaultOpenHub)
    }

    @Test("Defaults use ⌃⌥⌘, the previous defaults ⇧⌘")
    func defaultModifiers() {
        let hyper = UInt32(cmdKey | optionKey | controlKey)
        #expect(Shortcut.defaultOpenHub.modifiers == hyper)
        #expect(Shortcut.defaultCaptureScreenshot.modifiers == hyper)
        #expect(Shortcut.previousDefaultOpenHub.modifiers == UInt32(cmdKey | shiftKey))
        #expect(Shortcut.previousDefaultCaptureScreenshot.modifiers == UInt32(cmdKey | shiftKey))
    }

    @Test("Only Open Hub and Capture Area have a default")
    func defaultShortcutPerAction() {
        for action in ShortcutAction.allCases {
            let expected: Shortcut?
            switch action {
            case .openHub: expected = .defaultOpenHub
            case .captureScreenshot: expected = .defaultCaptureScreenshot
            default: expected = nil
            }
            #expect(ShortcutSet.defaultShortcut(for: action) == expected)
        }
    }

    @Test("Every action has a distinct, non-empty title")
    func titles() {
        let titles = ShortcutAction.allCases.map(\.title)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == titles.count)
    }

    @Test("A shortcut with no modifier is rejected")
    func missingModifiers() {
        let set = ShortcutSet(map: [.openHub: Shortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: 0)])
        #expect(ShortcutValidator.validationIssues(for: set)[.openHub]?.contains(.missingModifiers) == true)
    }

    @Test("⌘Q, ⌘W and ⌘, are reserved")
    func reserved() {
        for key in [kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_Comma] {
            let set = ShortcutSet(map: [.openHub: Shortcut(keyCode: UInt32(key), modifiers: UInt32(cmdKey))])
            #expect(ShortcutValidator.validationIssues(for: set)[.openHub]?.contains(.reservedShortcut) == true)
        }
        // Adding a modifier makes the same key legitimate.
        let allowed = ShortcutSet(map: [.openHub: Shortcut(keyCode: UInt32(kVK_ANSI_Q), modifiers: UInt32(cmdKey | optionKey))])
        #expect(ShortcutValidator.validationIssues(for: allowed).isEmpty)
    }

    @Test("A duplicate is reported on both actions, naming the other one")
    func duplicatesNameTheOther() {
        let shared = Shortcut.commandShift(kVK_ANSI_9)
        let set = ShortcutSet(map: [.captureWindow: shared, .captureFullScreen: shared])
        let issues = ShortcutValidator.validationIssues(for: set)
        #expect(issues[.captureWindow] == [.duplicate(with: .captureFullScreen)])
        #expect(issues[.captureFullScreen] == [.duplicate(with: .captureWindow)])
    }

    @Test("Issue messages name the conflicting action")
    func messages() {
        #expect(ShortcutValidationIssue.duplicate(with: .openHub).message == "Conflicts with Open Hub.")
        #expect(!ShortcutValidationIssue.reservedShortcut.message.isEmpty)
        #expect(!ShortcutValidationIssue.missingModifiers.message.isEmpty)
    }

    @Test("Modifier flags and the display prefix follow the stored modifiers")
    func modifierRendering() {
        let hyper = Shortcut.defaultOpenHub
        #expect(hyper.menuModifierFlags == [.control, .option, .command])
        #expect(hyper.displayString.hasPrefix("⌃⌥⌘"))

        let commandShift = Shortcut.commandShift(kVK_ANSI_2)
        #expect(commandShift.menuModifierFlags == [.shift, .command])
        #expect(commandShift.displayString.hasPrefix("⇧⌘"))
        #expect(!commandShift.displayString.hasPrefix("⌃"))
    }

    @Test("A shortcut set survives an encode and decode round trip")
    func codableRoundTrip() throws {
        let original = ShortcutSet(map: [
            .openHub: .defaultOpenHub,
            .captureWindow: .commandShift(kVK_ANSI_3)
        ])
        let decoded = try JSONDecoder().decode(ShortcutSet.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}
#endif
