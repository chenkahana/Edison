import AppKit
import SwiftUI

struct EditorWindowView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let session = appState.activeScreenshotSession {
                EditorSessionView(session: session)
                    .environmentObject(appState)
            } else {
                ContentUnavailableView("No Screenshot", systemImage: "photo")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            EditorWindowAccessor(
                onResolveWindow: { window in
                    guard let window else { return }
                    window.identifier = NSUserInterfaceItemIdentifier("editor-window")
                    window.minSize = NSSize(width: 920, height: 620)
                    appState.windowRouter?.registerEditorWindow(window)
                },
                onShouldClose: {
                    appState.requestEditorClose()
                    return false
                }
            )
        )
    }
}

private struct EditorSessionView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var session: ScreenshotSession

    @State private var tool: ScreenshotTool = .select
    @State private var draftSnapshot: ScreenshotDocumentSnapshot?
    @State private var dragContext: EditorDragContext?
    @State private var pendingText = ""
    @State private var textInsertionPoint: CGPoint?

    private let presetColors: [CodableColor] = [
        .systemRed,
        .systemOrange,
        CodableColor(nsColor: .systemBlue),
        CodableColor(nsColor: .systemGreen),
        CodableColor(nsColor: .labelColor)
    ]

    private var displayedSnapshot: ScreenshotDocumentSnapshot {
        draftSnapshot ?? session.currentSnapshot
    }

    private var visibleImageRect: CGRect {
        displayedSnapshot.cropRect ?? CGRect(origin: .zero, size: session.canvasSize)
    }

    private var currentSelection: ScreenshotAnnotation? {
        guard let selectedID = session.selectedAnnotationID else { return nil }
        return displayedSnapshot.annotations.first(where: { $0.id == selectedID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x4) {
            toolbar
            inspector
            canvas
        }
        .padding(HubTheme.Space.x5)
        .background(HubGlassBackground())
        .alert("Discard Changes?", isPresented: $appState.showEditorDiscardAlert) {
            Button("Discard", role: .destructive) {
                appState.discardAndCloseEditor()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This screenshot has changes that haven't been copied, saved, or kept yet.")
        }
        .onChange(of: session.id) { _, _ in
            resetTransientState()
        }
        .onDeleteCommand {
            session.deleteSelectedAnnotation()
        }
    }

    private var toolbar: some View {
        HStack(spacing: HubTheme.Space.x3) {
            Text("Screenshot Editor")
                .font(.headline)

            Picker("Tool", selection: $tool) {
                ForEach(ScreenshotTool.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 520)

            Spacer()

            Button("Undo") {
                commitPreviewIfNeeded()
                session.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!session.canUndo)

            Button("Redo") {
                commitPreviewIfNeeded()
                session.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!session.canRedo)

            Button("Copy") {
                commitPreviewIfNeeded()
                appState.copyActiveScreenshot()
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("Save") {
                commitPreviewIfNeeded()
                appState.saveActiveScreenshot()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Keep") {
                commitPreviewIfNeeded()
                appState.keepActiveScreenshot()
            }

            Button("Done") {
                commitPreviewIfNeeded()
                appState.requestEditorClose()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if let selection = currentSelection {
            HStack(spacing: HubTheme.Space.x3) {
                Text("Inspector")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: HubTheme.Space.x2) {
                    ForEach(presetColors, id: \.self) { color in
                        Button {
                            updateSelectedAnnotation { annotation in
                                annotation.color = color
                            }
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(selection.color == color ? Color.white : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                labeledStepper("Stroke", value: selection.lineWidth, range: 1...24) { newValue in
                    updateSelectedAnnotation { annotation in
                        annotation.lineWidth = newValue
                    }
                }

                if selection.kind == .text {
                    labeledStepper("Font", value: selection.fontSize, range: 14...96) { newValue in
                        updateSelectedAnnotation { annotation in
                            annotation.fontSize = newValue
                        }
                    }
                }

                if selection.kind == .redact {
                    labeledStepper("Blur", value: selection.blurRadius, range: 4...40) { newValue in
                        updateSelectedAnnotation { annotation in
                            annotation.blurRadius = newValue
                        }
                    }
                }

                Spacer()

                Button("Delete") {
                    session.deleteSelectedAnnotation()
                }
            }
            .padding(.horizontal, HubTheme.Space.x3)
            .padding(.vertical, HubTheme.Space.x2)
            .background(HubTheme.cardFillMuted, in: RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous))
        }
    }

    private var canvas: some View {
        GeometryReader { proxy in
            let baseFrame = fittedImageRect(in: proxy.size, imageSize: visibleImageRect.size)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
                    .fill(HubTheme.cardFillMuted)

                if let image = previewImage() {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: baseFrame.width, height: baseFrame.height)
                        .position(x: baseFrame.midX, y: baseFrame.midY)
                }

                annotationOverlay(displayRect: baseFrame)

                if let insertionPoint = textInsertionPoint {
                    textPopover(at: insertionPoint, displayRect: baseFrame)
                }

                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(displayRect: baseFrame))
            }
        }
    }

    private func annotationOverlay(displayRect: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(displayedSnapshot.annotations) { annotation in
                annotationShape(annotation, displayRect: displayRect)
            }
            if let selected = currentSelection {
                selectionOverlay(for: selected, displayRect: displayRect)
            }
        }
    }

    @ViewBuilder
    private func annotationShape(_ annotation: ScreenshotAnnotation, displayRect: CGRect) -> some View {
        switch annotation.kind {
        case .arrow:
            if let start = annotation.startPoint, let end = annotation.endPoint {
                Path { path in
                    path.move(to: toDisplayPoint(start, displayRect: displayRect))
                    path.addLine(to: toDisplayPoint(end, displayRect: displayRect))
                }
                .stroke(annotation.color.color, style: StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round))
            }

        case .rectangle:
            Rectangle()
                .path(in: frameFor(rect: annotation.rect, displayRect: displayRect))
                .stroke(annotation.color.color, lineWidth: annotation.lineWidth)

        case .text:
            Text(annotation.text)
                .font(.system(size: annotation.fontSize, weight: .semibold))
                .foregroundStyle(annotation.color.color)
                .position(center(of: frameFor(rect: annotation.rect, displayRect: displayRect)))

        case .redact:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(annotation.color.color.opacity(0.8), lineWidth: 2)
                )
                .frame(
                    width: frameFor(rect: annotation.rect, displayRect: displayRect).width,
                    height: frameFor(rect: annotation.rect, displayRect: displayRect).height
                )
                .position(center(of: frameFor(rect: annotation.rect, displayRect: displayRect)))
        }
    }

    private func selectionOverlay(for annotation: ScreenshotAnnotation, displayRect: CGRect) -> some View {
        let rect = frameFor(rect: annotation.bounds, displayRect: displayRect)
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .frame(width: rect.width, height: rect.height)
                .position(center(of: rect))

            ForEach(annotation.handles(), id: \.self) { handle in
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .position(toDisplayPoint(handle.point, displayRect: displayRect))
            }
        }
    }

    private func textPopover(at point: CGPoint, displayRect: CGRect) -> some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
            TextField("Text", text: $pendingText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            HStack {
                Button("Add") {
                    commitText(at: point)
                }
                Button("Cancel") {
                    pendingText = ""
                    textInsertionPoint = nil
                }
            }
        }
        .padding(HubTheme.Space.x3)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: HubTheme.Radius.menu, style: .continuous))
        .position(
            x: min(toDisplayPoint(point, displayRect: displayRect).x + 120, max(displayRect.maxX - 140, 140)),
            y: max(toDisplayPoint(point, displayRect: displayRect).y + 50, 70)
        )
    }

    private func dragGesture(displayRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let imagePoint = toImagePoint(value.location, displayRect: displayRect)
                guard visibleImageRect.contains(imagePoint) else { return }

                if dragContext == nil {
                    beginDrag(at: imagePoint)
                } else {
                    updateDrag(to: imagePoint)
                }
            }
            .onEnded { value in
                let imagePoint = toImagePoint(value.location, displayRect: displayRect)
                finishDrag(at: imagePoint)
            }
    }

    private func beginDrag(at point: CGPoint) {
        switch tool {
        case .select:
            if let handle = handle(at: point) {
                dragContext = .resize(handle: handle, start: point, base: displayedSnapshot)
                return
            }

            if let annotation = annotation(at: point) {
                session.selectedAnnotationID = annotation.id
                dragContext = .move(annotationID: annotation.id, start: point, base: displayedSnapshot)
            } else {
                session.selectedAnnotationID = nil
            }

        case .arrow, .rectangle, .redact, .crop:
            dragContext = .draw(tool: tool, start: point, base: displayedSnapshot)
            updateDraftPreview(for: tool, start: point, end: point, base: displayedSnapshot)

        case .text:
            session.selectedAnnotationID = nil
            textInsertionPoint = point
            pendingText = ""
        }
    }

    private func updateDrag(to point: CGPoint) {
        guard let dragContext else { return }

        switch dragContext {
        case let .move(annotationID, start, base):
            let delta = CGSize(width: point.x - start.x, height: point.y - start.y)
            var snapshot = base
            guard let index = snapshot.annotations.firstIndex(where: { $0.id == annotationID }) else { return }
            snapshot.annotations[index] = snapshot.annotations[index].moved(by: delta)
            draftSnapshot = snapshot

        case let .resize(handle, _, base):
            var snapshot = base
            guard let index = snapshot.annotations.firstIndex(where: { $0.id == handle.annotationID }) else { return }
            snapshot.annotations[index] = snapshot.annotations[index].resized(handle: handle.handle, to: point)
            draftSnapshot = snapshot

        case let .draw(tool, start, base):
            updateDraftPreview(for: tool, start: start, end: point, base: base)
        }
    }

    private func finishDrag(at point: CGPoint) {
        guard let dragContext else {
            return
        }

        switch dragContext {
        case .move, .resize, .draw:
            if let draftSnapshot, draftSnapshot != session.currentSnapshot {
                session.commit(snapshot: draftSnapshot)
            }
            self.draftSnapshot = nil
        }

        self.dragContext = nil
    }

    private func updateDraftPreview(for tool: ScreenshotTool, start: CGPoint, end: CGPoint, base: ScreenshotDocumentSnapshot) {
        var snapshot = base
        let rect = normalizedRect(start: start, end: end)
        switch tool {
        case .arrow:
            snapshot.annotations.append(
                .arrow(start: start, end: end, style: appState.settings.editor.defaultStyle)
            )
        case .rectangle:
            snapshot.annotations.append(.rectangle(rect, style: appState.settings.editor.defaultStyle))
        case .redact:
            snapshot.annotations.append(.redact(rect, style: appState.settings.editor.defaultStyle))
        case .crop:
            snapshot.cropRect = rect
        case .select, .text:
            break
        }

        if tool != .crop {
            snapshot.annotations = Array(base.annotations) + snapshot.annotations.suffix(1)
        }
        draftSnapshot = snapshot
    }

    private func commitPreviewIfNeeded() {
        if let draftSnapshot, draftSnapshot != session.currentSnapshot {
            session.commit(snapshot: draftSnapshot)
        }
        draftSnapshot = nil
        dragContext = nil
    }

    private func commitText(at point: CGPoint) {
        let trimmed = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            pendingText = ""
            textInsertionPoint = nil
            return
        }

        var snapshot = session.currentSnapshot
        snapshot.annotations.append(.text(trimmed, origin: point, style: appState.settings.editor.defaultStyle))
        session.commit(snapshot: snapshot)
        pendingText = ""
        textInsertionPoint = nil
    }

    private func updateSelectedAnnotation(_ mutate: (inout ScreenshotAnnotation) -> Void) {
        guard let currentSelection else { return }
        var snapshot = session.currentSnapshot
        guard let index = snapshot.annotations.firstIndex(where: { $0.id == currentSelection.id }) else { return }
        mutate(&snapshot.annotations[index])
        session.commit(snapshot: snapshot)
    }

    private func annotation(at point: CGPoint) -> ScreenshotAnnotation? {
        displayedSnapshot.annotations.reversed().first(where: { $0.contains(point) })
    }

    private func handle(at point: CGPoint) -> ScreenshotAnnotationHandle? {
        guard let selected = currentSelection else { return nil }
        return selected.handles().first(where: { hypot($0.point.x - point.x, $0.point.y - point.y) <= 12 })
    }

    private func previewImage() -> NSImage? {
        guard let baseImage = session.baseImage,
              let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let cropRect = visibleImageRect
        let scaleX = CGFloat(cgImage.width) / baseImage.size.width
        let scaleY = CGFloat(cgImage.height) / baseImage.size.height
        let scaledRect = CGRect(
            x: cropRect.origin.x * scaleX,
            y: cropRect.origin.y * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        ).integral

        guard let cropped = cgImage.cropping(to: scaledRect) else { return nil }
        return NSImage(cgImage: cropped, size: cropRect.size)
    }

    private func fittedImageRect(in available: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: available)
        }

        let scale = min(available.width / imageSize.width, available.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (available.width - fitted.width) * 0.5,
            y: (available.height - fitted.height) * 0.5,
            width: fitted.width,
            height: fitted.height
        )
    }

    private func toImagePoint(_ location: CGPoint, displayRect: CGRect) -> CGPoint {
        guard displayRect.width > 0, displayRect.height > 0 else { return .zero }
        let normalizedX = ((location.x - displayRect.minX) / displayRect.width).clamped(to: 0...1)
        let normalizedY = ((location.y - displayRect.minY) / displayRect.height).clamped(to: 0...1)
        return CGPoint(
            x: visibleImageRect.minX + normalizedX * visibleImageRect.width,
            y: visibleImageRect.minY + (1 - normalizedY) * visibleImageRect.height
        )
    }

    private func toDisplayPoint(_ point: CGPoint, displayRect: CGRect) -> CGPoint {
        guard visibleImageRect.width > 0, visibleImageRect.height > 0 else { return .zero }
        let normalizedX = ((point.x - visibleImageRect.minX) / visibleImageRect.width).clamped(to: 0...1)
        let normalizedY = ((point.y - visibleImageRect.minY) / visibleImageRect.height).clamped(to: 0...1)
        return CGPoint(
            x: displayRect.minX + normalizedX * displayRect.width,
            y: displayRect.minY + (1 - normalizedY) * displayRect.height
        )
    }

    private func frameFor(rect: CGRect, displayRect: CGRect) -> CGRect {
        let origin = toDisplayPoint(CGPoint(x: rect.minX, y: rect.maxY), displayRect: displayRect)
        let opposite = toDisplayPoint(CGPoint(x: rect.maxX, y: rect.minY), displayRect: displayRect)
        return CGRect(
            x: min(origin.x, opposite.x),
            y: min(origin.y, opposite.y),
            width: abs(opposite.x - origin.x),
            height: abs(opposite.y - origin.y)
        )
    }

    private func center(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    private func normalizedRect(start: CGPoint, end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func labeledStepper(_ title: String, value: Double, range: ClosedRange<Double>, apply: @escaping (Double) -> Void) -> some View {
        HStack(spacing: HubTheme.Space.x2) {
            Text(title)
                .foregroundStyle(HubTheme.textSecondary)
            Stepper(
                "\(Int(value.rounded()))",
                value: Binding(
                    get: { value },
                    set: { apply($0.clamped(to: range)) }
                ),
                in: range,
                step: 1
            )
            .labelsHidden()
        }
    }

    private func resetTransientState() {
        tool = .select
        draftSnapshot = nil
        dragContext = nil
        pendingText = ""
        textInsertionPoint = nil
    }
}

private enum EditorDragContext {
    case move(annotationID: UUID, start: CGPoint, base: ScreenshotDocumentSnapshot)
    case resize(handle: ScreenshotAnnotationHandle, start: CGPoint, base: ScreenshotDocumentSnapshot)
    case draw(tool: ScreenshotTool, start: CGPoint, base: ScreenshotDocumentSnapshot)
}

private struct EditorWindowAccessor: NSViewRepresentable {
    let onResolveWindow: (NSWindow?) -> Void
    let onShouldClose: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.attach(to: nsView)
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var parent: EditorWindowAccessor
        weak var view: NSView?
        weak var window: NSWindow?

        init(parent: EditorWindowAccessor) {
            self.parent = parent
        }

        func attach(to view: NSView) {
            self.view = view
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let resolvedWindow = view.window
                guard self.window !== resolvedWindow else { return }
                self.window?.delegate = nil
                self.window = resolvedWindow
                self.window?.delegate = self
                self.parent.onResolveWindow(resolvedWindow)
            }
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            parent.onShouldClose()
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
