import Carbon
import Foundation

final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?
    private var bindings: [UInt32: ShortcutAction] = [:]
    private var callback: ((ShortcutAction) -> Void)?

    private init() {
        installHandlerIfNeeded()
    }

    func updateHandler(_ callback: @escaping (ShortcutAction) -> Void) {
        self.callback = callback
    }

    func apply(shortcuts: ShortcutSet) {
        unregisterAll()
        bindings.removeAll()

        for (index, action) in ShortcutAction.allCases.enumerated() {
            guard let shortcut = shortcuts.map[action] else { continue }
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: fourCharCode(from: "EDSN"), id: UInt32(index + 1))
            RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            hotKeyRefs.append(hotKeyRef)
            bindings[hotKeyID.id] = action
        }
    }

    private func unregisterAll() {
        hotKeyRefs.forEach {
            if let ref = $0 {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData else { return noErr }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                return center.handle(eventRef: eventRef)
            },
            1,
            &eventType,
            pointer,
            &eventHandler
        )
    }

    private func handle(eventRef: EventRef?) -> OSStatus {
        guard let eventRef else { return noErr }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, let action = bindings[hotKeyID.id] else {
            return status
        }

        callback?(action)
        return noErr
    }

    private func fourCharCode(from string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
