import AppKit
import ApplicationServices
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

        let pasteKeyCode: CGKeyCode = 9 // kVK_ANSI_V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: pasteKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: pasteKeyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
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
