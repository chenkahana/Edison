import Foundation
#if canImport(AppKit)
import AppKit
#endif
@testable import Edison

// MARK: - Item factories

func makeTextItem(_ value: String) -> ClipboardItem {
    ClipboardItem(payload: .text(value))
}

func makeTestImageData(size: NSSize = NSSize(width: 80, height: 60)) -> Data {
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
    image.unlockFocus()

    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

// MARK: - Legacy shortcut migration fixtures

enum LegacyShortcutActionTest: String, Codable, Hashable {
    case openHub
    case captureArea
    case captureWindow
    case captureFullScreen
}

struct LegacyShortcutSetTest: Codable {
    var map: [LegacyShortcutActionTest: Shortcut]
}

// MARK: - UserDefaults helpers

/// Returns an isolated UserDefaults suite for testing. Caller is responsible for cleanup
/// (call `defaults.removePersistentDomain(forName: suiteName)` when done).
func makeTestDefaults(label: String = "Test") -> (suiteName: String, defaults: UserDefaults) {
    let suiteName = "EdisonTests.\(label).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    return (suiteName, defaults)
}
