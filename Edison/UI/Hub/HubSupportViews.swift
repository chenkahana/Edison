import AppKit
import Quartz
import SwiftUI

// MARK: - ContentSizeReader

struct ContentSizeReader: View {
    @Binding var width: CGFloat
    @Binding var height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    width = proxy.size.width
                    height = proxy.size.height
                }
                .onChange(of: proxy.size) { _, newValue in
                    width = newValue.width
                    height = newValue.height
                }
        }
    }
}

// MARK: - HubItemIconView

struct HubItemIconView: View {
    let icon: HubItemIcon
    let tint: Color
    let size: CGFloat

    var body: some View {
        Group {
            switch icon {
            case let .system(name):
                Image(systemName: name)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(tint)
            case let .app(image):
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size + 3, height: size + 3)
                    .clipShape(RoundedRectangle(cornerRadius: max(3, size * 0.3), style: .continuous))
            }
        }
    }
}

// MARK: - ClipboardSourceApplicationIconProvider

enum ClipboardSourceApplicationIconProvider {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for sourceApplication: ClipboardSourceApplication?) -> NSImage? {
        guard let bundleIdentifier = sourceApplication?.bundleIdentifier else {
            return nil
        }

        let key = bundleIdentifier as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

// MARK: - HubClipboardTextView
// Used by both HubShelfCardView and HubListRowView (W3.2).

struct HubClipboardTextView: View {
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let lineLimit: Int?

    private let content: HubStructuredTextContent

    init(text: String, fontSize: CGFloat, fontWeight: Font.Weight, lineLimit: Int?) {
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.lineLimit = lineLimit
        self.content = HubStructuredTextFormatter.content(for: text)
    }

    var body: some View {
        Group {
            switch content {
            case let .plain(text):
                Text(text)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundStyle(HubTheme.textPrimary)
            case let .json(text):
                Text(text)
                    .font(.system(size: max(fontSize - 1, 12), weight: .regular, design: .monospaced))
                    .foregroundStyle(HubTheme.textPrimary)
            case let .markdown(text):
                Text(text)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundStyle(HubTheme.textPrimary)
                    .tint(HubTheme.accentBrand)
            }
        }
        .multilineTextAlignment(.leading)
        .lineLimit(lineLimit)
    }
}

// MARK: - HubToastView

struct HubToastView: View {
    let title: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: HubTheme.Space.x3) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(HubTheme.textPrimary)
            Button(buttonTitle, action: action)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HubTheme.accentBrand)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, HubTheme.Space.x5)
        .padding(.vertical, HubTheme.Space.x3)
        .background(
            Capsule(style: .continuous)
                .fill(HubTheme.cardFill)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(HubTheme.glassStroke, lineWidth: 1)
        )
    }
}

// MARK: - HubCaptureErrorBanner

struct HubCaptureErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: HubTheme.Space.x3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(HubTheme.textPrimary)
                .lineLimit(1)
            Spacer()
            Button("Screen Recording") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                )
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(HubTheme.accentBrand)
            .buttonStyle(.plain)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(HubTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, HubTheme.Space.x5)
        .padding(.vertical, HubTheme.Space.x3)
        .background(
            Capsule(style: .continuous)
                .fill(HubTheme.cardFill)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(HubTheme.glassStroke, lineWidth: 1)
        )
    }
}

// MARK: - HubItemActionMenu

struct HubItemActionMenu: View {
    let item: ClipboardItem
    let collections: [ItemCollection]
    let isInCollection: (UUID) -> Bool
    let onPaste: () -> Void
    let onPasteAsPlainText: () -> Void
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleCollectionMembership: (UUID) -> Void
    let onExport: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button("Paste", action: onPaste)
        if case .text = item.payload {
            Button("Paste as Plain Text", action: onPasteAsPlainText)
                .keyboardShortcut(.return, modifiers: [.shift])
                .accessibilityLabel("Paste as Plain Text")
        }
        Button("Copy", action: onCopy)
        Divider()
        Button(item.isFavorite ? "Remove Favorite" : "Add Favorite", action: onToggleFavorite)
        if !collections.isEmpty {
            Menu("Collections") {
                ForEach(collections) { collection in
                    Button {
                        onToggleCollectionMembership(collection.id)
                    } label: {
                        Label(
                            collection.name,
                            systemImage: isInCollection(collection.id) ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
            }
        }
        Divider()
        Button("Export", action: onExport)
        Button("Share", action: onShare)
        Divider()
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - HubWindowAccessor

struct HubWindowAccessor: NSViewRepresentable {
    let onResolveWindow: (NSWindow?) -> Void
    let onMoveCommand: (MoveCommandDirection) -> Void
    let onConfirmSelection: () -> Void
    let onConfirmPlainTextSelection: () -> Void
    let onDismiss: () -> Void
    let onFocusSearch: () -> Void
    let onTypeSearch: (String) -> Void
    let onDeleteSearchCharacter: () -> Void
    let onDeleteItem: () -> Void
    let onQuickLook: () -> Void
    let onQuickPaste: (Int) -> Void

    static func confirmMode(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> ClipboardWriteMode? {
        guard keyCode == 36 || keyCode == 76 else { return nil }
        let modifiers = modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting(.numericPad)
        if modifiers == [.shift] { return .plainText }
        if modifiers.isEmpty { return .sourceFormatting }
        return nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> HubWindowReaderView {
        let view = HubWindowReaderView()
        view.onResolveWindow = onResolveWindow
        view.onAttachWindow = { [weak coordinator = context.coordinator] hostView, window in
            coordinator?.attach(view: hostView, to: window)
        }
        view.onKeyDown = { [weak coordinator = context.coordinator] event in
            coordinator?.handleKeyDown(event) ?? false
        }
        return view
    }

    func updateNSView(_ nsView: HubWindowReaderView, context: Context) {
        context.coordinator.parent = self
        nsView.onResolveWindow = onResolveWindow
        nsView.onKeyDown = { [weak coordinator = context.coordinator] event in
            coordinator?.handleKeyDown(event) ?? false
        }
        nsView.resolveWindow()
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var parent: HubWindowAccessor
        private weak var window: NSWindow?
        private weak var readerView: HubWindowReaderView?

        init(parent: HubWindowAccessor) {
            self.parent = parent
        }

        func attach(view: HubWindowReaderView, to window: NSWindow?) {
            guard self.window !== window || self.readerView !== view else {
                parent.onResolveWindow(window)
                return
            }

            self.window?.delegate = nil
            self.readerView = view
            self.window = window
            self.window?.delegate = self
            parent.onResolveWindow(window)
            focusKeyboardHost()
        }

        func windowDidBecomeKey(_ notification: Notification) {
            focusKeyboardHost()
        }

        func windowDidResignKey(_ notification: Notification) {
            guard let window,
                  window.attachedSheet == nil,
                  window.childWindows?.isEmpty ?? true else { return }
            parent.onDismiss()
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard sender.attachedSheet == nil,
                  sender.childWindows?.isEmpty ?? true else { return false }
            parent.onDismiss()
            return false
        }

        private func focusKeyboardHost() {
            guard let window,
                  let readerView else { return }

            DispatchQueue.main.async {
                guard window.isKeyWindow else { return }
                window.makeFirstResponder(readerView)
            }
        }

        func handleKeyDown(_ event: NSEvent) -> Bool {
            guard let window,
                  event.window == window || window.isKeyWindow else { return false }

            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
               event.charactersIgnoringModifiers?.lowercased() == "f" {
                parent.onFocusSearch()
                return true
            }

            // Cmd+Delete → delete selected item
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
               event.keyCode == 51 {
                parent.onDeleteItem()
                return true
            }

            // Cmd+1-9 → quick paste
            let quickPasteKeyCodes: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8]
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
               let idx = quickPasteKeyCodes[event.keyCode] {
                parent.onQuickPaste(idx)
                return true
            }

            if let mode = HubWindowAccessor.confirmMode(
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags
            ) {
                if mode == .plainText {
                    parent.onConfirmPlainTextSelection()
                } else {
                    parent.onConfirmSelection()
                }
                return true
            }

            if let text = printableSearchText(from: event) {
                parent.onTypeSearch(text)
                return true
            }

            switch event.keyCode {
            case 49: // Space → Quick Look
                parent.onQuickLook()
                return true
            case 51, 117:
                parent.onDeleteSearchCharacter()
                return true
            case 123:
                parent.onMoveCommand(.left)
                return true
            case 124:
                parent.onMoveCommand(.right)
                return true
            case 125:
                parent.onMoveCommand(.down)
                return true
            case 126:
                parent.onMoveCommand(.up)
                return true
            case 53:
                parent.onDismiss()
                return true
            default:
                return false
            }
        }

        private func printableSearchText(from event: NSEvent) -> String? {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.isEmpty || modifiers == [.shift] else { return nil }
            guard let characters = event.characters, !characters.isEmpty else { return nil }
            guard characters.rangeOfCharacter(from: .controlCharacters.union(.whitespacesAndNewlines)) == nil else {
                return nil
            }
            return characters
        }
    }

    final class HubWindowReaderView: NSView {
        var onResolveWindow: (NSWindow?) -> Void = { _ in }
        var onAttachWindow: (HubWindowReaderView, NSWindow?) -> Void = { _, _ in }
        var onKeyDown: (NSEvent) -> Bool = { _ in false }

        override var acceptsFirstResponder: Bool { true }
        override var canBecomeKeyView: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindow()
        }

        override func keyDown(with event: NSEvent) {
            if onKeyDown(event) {
                return
            }
            super.keyDown(with: event)
        }

        func resolveWindow() {
            let window = self.window
            onAttachWindow(self, window)
            onResolveWindow(window)
        }
    }
}

// MARK: - QuickLookBridge

struct QuickLookBridge: NSViewRepresentable {
    let url: URL
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.open(url: url)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        if isPresented {
            context.coordinator.open(url: url)
        } else {
            QLPreviewPanel.shared()?.close()
        }
    }

    final class Coordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
        var parent: QuickLookBridge

        init(parent: QuickLookBridge) {
            self.parent = parent
        }

        func open(url: URL) {
            let panel = QLPreviewPanel.shared()!
            panel.dataSource = self
            panel.delegate = self
            panel.reloadData()
            if !panel.isVisible { panel.makeKeyAndOrderFront(nil) }
        }

        func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { 1 }

        func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
            parent.url as NSURL
        }

        func previewPanelDidClose(_ panel: QLPreviewPanel!) {
            parent.isPresented = false
        }
    }
}
