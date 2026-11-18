import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum PasteSelectionResolver {
    static func resolve(from items: [ClipboardItem], selectedItemID: UUID?) -> ClipboardItem? {
        if let selectedItemID,
           let selectedItem = items.first(where: { $0.id == selectedItemID }) {
            return selectedItem
        }

        return items.first
    }
}

@MainActor
struct PasteBackCoordinator {
    typealias ClipboardWriter = (ClipboardItem, ClipboardWriteMode) -> Bool
    typealias LegacyClipboardWriter = (ClipboardItem) -> Bool
    typealias AccessibilityTrustProvider = () -> Bool
    typealias TargetAppActivator = (NSRunningApplication) -> Void
    typealias TargetAppReadinessChecker = (NSRunningApplication) -> Bool
    typealias DelayScheduler = (_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> Void
    typealias PasteDispatcher = (pid_t) -> Void
    typealias HubCloser = () -> Void
    typealias AccessibilityDeniedHandler = () -> Void
    typealias CompletionHandler = () -> Void

    let restoreDelay: TimeInterval
    let activationRetryInterval: TimeInterval
    let activationTimeout: TimeInterval

    private let writeItemToClipboard: ClipboardWriter
    private let isAccessibilityTrusted: AccessibilityTrustProvider
    private let activateTargetApp: TargetAppActivator
    private let isTargetAppReady: TargetAppReadinessChecker
    private let scheduleDelay: DelayScheduler
    private let dispatchPaste: PasteDispatcher
    private let closeHub: HubCloser

    init(
        restoreDelay: TimeInterval = 0.12,
        activationRetryInterval: TimeInterval = 0.04,
        activationTimeout: TimeInterval = 0.6,
        writeItemToClipboard: @escaping ClipboardWriter,
        isAccessibilityTrusted: @escaping AccessibilityTrustProvider = { AXIsProcessTrusted() },
        activateTargetApp: @escaping TargetAppActivator = { targetApp in
            targetApp.unhide()
            targetApp.activate(options: [])
        },
        isTargetAppReady: @escaping TargetAppReadinessChecker = { targetApp in
            targetApp.isActive || NSWorkspace.shared.frontmostApplication?.processIdentifier == targetApp.processIdentifier
        },
        scheduleDelay: @escaping DelayScheduler = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                action()
            }
        },
        dispatchPaste: @escaping PasteDispatcher = Self.dispatchPaste(to:),
        closeHub: @escaping HubCloser
    ) {
        self.restoreDelay = restoreDelay
        self.activationRetryInterval = activationRetryInterval
        self.activationTimeout = activationTimeout
        self.writeItemToClipboard = writeItemToClipboard
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.activateTargetApp = activateTargetApp
        self.isTargetAppReady = isTargetAppReady
        self.scheduleDelay = scheduleDelay
        self.dispatchPaste = dispatchPaste
        self.closeHub = closeHub
    }

    init(
        restoreDelay: TimeInterval = 0.12,
        activationRetryInterval: TimeInterval = 0.04,
        activationTimeout: TimeInterval = 0.6,
        writeItemToClipboard: @escaping LegacyClipboardWriter,
        isAccessibilityTrusted: @escaping AccessibilityTrustProvider = { AXIsProcessTrusted() },
        activateTargetApp: @escaping TargetAppActivator = { targetApp in
            targetApp.unhide()
            targetApp.activate(options: [])
        },
        isTargetAppReady: @escaping TargetAppReadinessChecker = { targetApp in
            targetApp.isActive || NSWorkspace.shared.frontmostApplication?.processIdentifier == targetApp.processIdentifier
        },
        scheduleDelay: @escaping DelayScheduler = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                action()
            }
        },
        dispatchPaste: @escaping PasteDispatcher = Self.dispatchPaste(to:),
        closeHub: @escaping HubCloser
    ) {
        let adaptedWriter: ClipboardWriter = { item, _ in writeItemToClipboard(item) }
        self.init(
            restoreDelay: restoreDelay,
            activationRetryInterval: activationRetryInterval,
            activationTimeout: activationTimeout,
            writeItemToClipboard: adaptedWriter,
            isAccessibilityTrusted: isAccessibilityTrusted,
            activateTargetApp: activateTargetApp,
            isTargetAppReady: isTargetAppReady,
            scheduleDelay: scheduleDelay,
            dispatchPaste: dispatchPaste,
            closeHub: closeHub
        )
    }

    func run(
        item: ClipboardItem,
        targetApp: NSRunningApplication?,
        mode: ClipboardWriteMode = .sourceFormatting,
        onAccessibilityDenied: @escaping AccessibilityDeniedHandler = {},
        completion: @escaping CompletionHandler = {}
    ) {
        guard writeItemToClipboard(item, mode) else {
            completion()
            return
        }

        guard isAccessibilityTrusted() else {
            onAccessibilityDenied()
            completion()
            return
        }

        guard let targetApp else {
            closeHub()
            completion()
            return
        }

        closeHub()
        waitForTargetAppToBecomeReady(targetApp, remainingWait: activationTimeout, completion: completion)
    }

    nonisolated private static func dispatchPaste(to pid: pid_t) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        let pasteKeyCode = commandVKeyCode()
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: pasteKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: pasteKeyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
    }

    /// The key that types "v" with ⌘ held in the current keyboard layout, so paste is ⌘V on Dvorak, Colemak and
    /// "Dvorak - QWERTY ⌘" alike. Falls back to the ANSI V key when the layout has no Unicode key map or no V.
    nonisolated private static func commandVKeyCode() -> CGKeyCode {
        let ansiV = CGKeyCode(kVK_ANSI_V)
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return ansiV
        }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return ansiV }

        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        let commandModifier = UInt32((cmdKey >> 8) & 0xFF)
        let v = UniChar(("v" as Unicode.Scalar).value)
        for keyCode in [ansiV] + (0..<128).map(CGKeyCode.init) {
            var deadKeyState: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDown),
                commandModifier,
                UInt32(LMGetKbdType()),
                OptionBits(1 << kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
            if status == noErr, length == 1, characters[0] == v {
                return keyCode
            }
        }
        return ansiV
    }

    private func waitForTargetAppToBecomeReady(
        _ targetApp: NSRunningApplication,
        remainingWait: TimeInterval,
        completion: @escaping CompletionHandler
    ) {
        activateTargetApp(targetApp)

        let delay = remainingWait >= activationTimeout ? restoreDelay : min(activationRetryInterval, remainingWait)
        let clampedDelay = max(0, delay)
        scheduleDelay(clampedDelay) {
            let pid = targetApp.processIdentifier
            if isTargetAppReady(targetApp) {
                dispatchPaste(pid)
                completion()
                return
            }

            let updatedRemainingWait = max(0, remainingWait - clampedDelay)
            guard updatedRemainingWait > 0 else {
                completion()
                return
            }

            waitForTargetAppToBecomeReady(targetApp, remainingWait: updatedRemainingWait, completion: completion)
        }
    }
}
