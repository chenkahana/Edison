import AppKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

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

private struct EditorTextDraft: Equatable {
    /// Top-left of the text in image coordinates.
    var topLeft: CGPoint
    var text: String
    var editingID: UUID?
}

private struct EditorSessionView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var session: ScreenshotSession

    @State private var tool: ScreenshotTool = .arrow
    @State private var draftSnapshot: ScreenshotDocumentSnapshot?
    @State private var dragContext: EditorDragContext?
    @State private var cropDraft: CGRect?
    @State private var textDraft: EditorTextDraft?
    @FocusState private var isTextFieldFocused: Bool

    private static let palette: [CodableColor] = [
        .systemRed,
        .systemOrange,
        CodableColor(nsColor: .systemYellow),
        CodableColor(nsColor: .systemGreen),
        CodableColor(nsColor: .systemBlue),
        CodableColor(nsColor: .systemPurple),
        CodableColor(red: 1, green: 1, blue: 1),
        CodableColor(red: 0.08, green: 0.08, blue: 0.09)
    ]

    private var style: AnnotationStyleSettings { appState.settings.editor.defaultStyle }

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

    private var activeColor: CodableColor { currentSelection?.color ?? style.color }

    private var activeSize: AnnotationSizePreset {
        AnnotationSizePreset.nearest(toLineWidth: currentSelection?.lineWidth ?? style.lineWidth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x3) {
            toolbar
            styleBar
            canvas
        }
        .padding(HubTheme.Space.x5)
        .background(HubGlassBackground())
        .background(EditorKeyMonitor(handler: handleKey))
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
        .onChange(of: tool) { _, _ in
            commitTextIfNeeded()
            cropDraft = nil
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: HubTheme.Space.x3) {
            HStack(spacing: 2) {
                ForEach(ScreenshotTool.allCases) { item in
                    EditorToolButton(tool: item, isSelected: tool == item) {
                        tool = item
                    }
                }
            }
            .padding(3)
            .background(HubTheme.cardFillMuted, in: RoundedRectangle(cornerRadius: HubTheme.Radius.menu, style: .continuous))

            Spacer(minLength: HubTheme.Space.x2)

            HStack(spacing: 2) {
                iconButton("arrow.uturn.backward", help: "Undo (⌘Z)") {
                    commitPreviewIfNeeded()
                    session.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!session.canUndo)

                iconButton("arrow.uturn.forward", help: "Redo (⇧⌘Z)") {
                    commitPreviewIfNeeded()
                    session.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!session.canRedo)
            }

            dragOutChip

            Button("Save") {
                commitPreviewIfNeeded()
                appState.saveActiveScreenshot()
            }
            .keyboardShortcut("s", modifiers: .command)
            .help("Save as PNG (⌘S)")

            Button("Keep") {
                commitPreviewIfNeeded()
                appState.keepActiveScreenshot()
            }
            .help("Keep in Edison history without copying")

            Button("Copy") {
                commitPreviewIfNeeded()
                appState.copyActiveScreenshot()
            }
            .keyboardShortcut("c", modifiers: .command)
            .help("Copy to clipboard (⌘C) · Copy and close (⌘↩)")

            Button("Done") {
                commitPreviewIfNeeded()
                appState.requestEditorClose()
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.borderedProminent)
            .tint(HubTheme.accentBrand)
        }
        .controlSize(.regular)
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(help)
    }

    /// Drag the finished image straight into Finder, Mail, Slack, or any drop target.
    private var dragOutChip: some View {
        HStack(spacing: HubTheme.Space.x2) {
            if let thumbnail = basePreviewImage() {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
                    .frame(width: 30, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            Text("Drag")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HubTheme.textSecondary)
        }
        .padding(.horizontal, HubTheme.Space.x2)
        .padding(.vertical, 4)
        .background(HubTheme.cardFillMuted, in: Capsule(style: .continuous))
        .onDrag { makeDragItemProvider() }
        .help("Drag the annotated image into any app")
        .accessibilityLabel("Drag annotated image")
    }

    // MARK: - Style bar

    private var styleBar: some View {
        HStack(spacing: HubTheme.Space.x4) {
            HStack(spacing: HubTheme.Space.x2) {
                ForEach(Self.palette, id: \.self) { color in
                    Button {
                        apply(color: color)
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 1))
                            .overlay(
                                Circle()
                                    .strokeBorder(HubTheme.accentBrand, lineWidth: 2)
                                    .padding(-4)
                                    .opacity(activeColor == color ? 1 : 0)
                            )
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Colour")
                }
            }

            Picker("Size", selection: Binding(get: { activeSize }, set: { apply(size: $0) })) {
                ForEach(AnnotationSizePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 150)
            .help("Size & thickness (⌘[ / ⌘])")

            if currentSelection != nil {
                Button(role: .destructive) {
                    session.deleteSelectedAnnotation()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }

            if session.currentSnapshot.cropRect != nil {
                Button {
                    var snapshot = session.currentSnapshot
                    snapshot.cropRect = nil
                    session.commit(snapshot: snapshot)
                } label: {
                    Label("Reset Crop", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.borderless)
            }

            Spacer(minLength: 0)

            Text(hintText)
                .font(.system(size: 11))
                .foregroundStyle(HubTheme.textTertiary)
                .lineLimit(1)
                .truncationMode(.head)

            Text("\(Int(visibleImageRect.width)) × \(Int(visibleImageRect.height))")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(HubTheme.textSecondary)
        }
        .padding(.horizontal, HubTheme.Space.x3)
        .padding(.vertical, HubTheme.Space.x1)
        .background(HubTheme.cardFillMuted, in: RoundedRectangle(cornerRadius: HubTheme.Radius.menu, style: .continuous))
    }

    private var hintText: String {
        switch tool {
        case .select: return "Drag to move · arrows nudge · ⌘D duplicate · ⌫ delete"
        case .arrow, .line: return "⇧ snaps to 45°"
        case .rectangle, .ellipse: return "⇧ draws a square or circle"
        case .pen, .highlighter: return "Draw freely"
        case .text: return "Click to type · click text to edit · ↩ to finish"
        case .counter: return "Click to drop the next number"
        case .redact: return "Drag over anything private"
        case .crop: return "Drag to crop · ⇧ for square"
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { proxy in
            let displayRect = fittedImageRect(in: proxy.size, imageSize: visibleImageRect.size)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
                    .fill(HubTheme.cardFillMuted)

                if let image = basePreviewImage() {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: displayRect.width, height: displayRect.height)
                        .position(x: displayRect.midX, y: displayRect.midY)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                }

                annotationCanvas(displayRect: displayRect)

                if let selected = currentSelection, textDraft?.editingID != selected.id {
                    selectionOverlay(for: selected, displayRect: displayRect)
                }

                if let cropDraft {
                    cropOverlay(cropDraft, displayRect: displayRect)
                }

                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(displayRect: displayRect))
                    .onContinuousHover { phase in
                        switch phase {
                        case .active:
                            (tool == .select ? NSCursor.arrow : NSCursor.crosshair).set()
                        case .ended:
                            NSCursor.arrow.set()
                        }
                    }

                if let textDraft {
                    textEditor(textDraft, displayRect: displayRect)
                }
            }
        }
    }

    /// Draws annotations with the same renderer used for export.
    private func annotationCanvas(displayRect: CGRect) -> some View {
        let visible = visibleImageRect
        let hiddenID = textDraft?.editingID
        let annotations = displayedSnapshot.annotations.filter { $0.id != hiddenID }

        return Canvas { context, _ in
            guard visible.width > 0, visible.height > 0 else { return }
            let scale = displayRect.width / visible.width
            context.withCGContext { cgContext in
                cgContext.translateBy(x: displayRect.minX, y: displayRect.maxY)
                cgContext.scaleBy(x: scale, y: -displayRect.height / visible.height)
                cgContext.translateBy(x: -visible.minX, y: -visible.minY)
                cgContext.clip(to: visible)
                session.drawAnnotations(annotations, in: cgContext, displayScale: scale)
            }
        }
        .allowsHitTesting(false)
    }

    private func selectionOverlay(for annotation: ScreenshotAnnotation, displayRect: CGRect) -> some View {
        let rect = frameFor(rect: annotation.bounds, displayRect: displayRect).insetBy(dx: -4, dy: -4)
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .shadow(color: .black.opacity(0.5), radius: 1)
                .frame(width: rect.width, height: rect.height)
                .position(center(of: rect))

            ForEach(annotation.handles(), id: \.self) { handle in
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(HubTheme.accentBrand, lineWidth: 2))
                    .frame(width: 11, height: 11)
                    .shadow(color: .black.opacity(0.35), radius: 1.5)
                    .position(toDisplayPoint(handle.point, displayRect: displayRect))
            }
        }
        .allowsHitTesting(false)
    }

    private func cropOverlay(_ crop: CGRect, displayRect: CGRect) -> some View {
        let frame = frameFor(rect: crop, displayRect: displayRect)
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(displayRect)
                path.addRect(frame)
            }
            .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))

            Rectangle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: frame.width, height: frame.height)
                .position(center(of: frame))

            Text("\(Int(crop.width)) × \(Int(crop.height))")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.7), in: Capsule())
                .position(x: frame.midX, y: max(frame.minY - 14, displayRect.minY + 12))
        }
        .allowsHitTesting(false)
    }

    private func textEditor(_ draft: EditorTextDraft, displayRect: CGRect) -> some View {
        let scale = visibleImageRect.width > 0 ? displayRect.width / visibleImageRect.width : 1
        let fontSize = (currentSelection?.id == draft.editingID ? currentSelection?.fontSize : nil) ?? style.fontSize
        let topLeft = toDisplayPoint(draft.topLeft, displayRect: displayRect)
        let color = (draft.editingID.flatMap { id in session.currentSnapshot.annotations.first { $0.id == id }?.color }) ?? style.color

        return TextField(
            "Type here",
            text: Binding(
                get: { textDraft?.text ?? "" },
                set: { textDraft?.text = $0 }
            )
        )
        .textFieldStyle(.plain)
        .font(Font(ScreenshotAnnotationRenderer.textFont(size: max(fontSize * scale, 11))))
        .foregroundStyle(color.color)
        .shadow(color: .black.opacity(0.45), radius: 2)
        .fixedSize()
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .focused($isTextFieldFocused)
        .onSubmit { commitTextIfNeeded() }
        .offset(x: topLeft.x - 4, y: topLeft.y)
        .onAppear { isTextFieldFocused = true }
    }

    // MARK: - Gestures

    private func dragGesture(displayRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let imagePoint = toImagePoint(value.location, displayRect: displayRect)
                let shift = NSEvent.modifierFlags.contains(.shift)
                if dragContext == nil {
                    beginDrag(at: imagePoint)
                } else {
                    updateDrag(to: imagePoint, constrained: shift)
                }
            }
            .onEnded { _ in
                finishDrag()
            }
    }

    private func beginDrag(at point: CGPoint) {
        if textDraft != nil {
            commitTextIfNeeded()
            dragContext = .ignored
            return
        }

        // Handles and the selected mark stay directly manipulable from every tool.
        if let handle = handle(at: point) {
            dragContext = .resize(handle: handle, base: displayedSnapshot)
            return
        }
        if tool != .text, let selected = currentSelection, selected.contains(point) {
            dragContext = .move(annotationID: selected.id, start: point, base: displayedSnapshot)
            return
        }

        switch tool {
        case .select:
            if let annotation = annotation(at: point) {
                session.selectedAnnotationID = annotation.id
                dragContext = .move(annotationID: annotation.id, start: point, base: displayedSnapshot)
            } else {
                session.selectedAnnotationID = nil
                dragContext = .ignored
            }

        case .arrow, .line, .rectangle, .ellipse, .redact:
            session.selectedAnnotationID = nil
            dragContext = .draw(tool: tool, start: point, base: displayedSnapshot)

        case .pen, .highlighter:
            session.selectedAnnotationID = nil
            let kind: ScreenshotAnnotationKind = tool == .pen ? .pen : .highlighter
            let annotation = ScreenshotAnnotation.freehand(kind, points: [point], style: style)
            dragContext = .freehand(annotationID: annotation.id, base: displayedSnapshot)
            var snapshot = displayedSnapshot
            snapshot.annotations.append(annotation)
            draftSnapshot = snapshot

        case .counter:
            let annotation = ScreenshotAnnotation.counter(session.nextCounterNumber, center: point, style: style)
            var snapshot = displayedSnapshot
            snapshot.annotations.append(annotation)
            draftSnapshot = snapshot
            session.selectedAnnotationID = annotation.id
            dragContext = .move(annotationID: annotation.id, start: point, base: snapshot)

        case .text:
            if let existing = annotation(at: point), existing.kind == .text {
                session.selectedAnnotationID = existing.id
                textDraft = EditorTextDraft(
                    topLeft: CGPoint(x: existing.rect.minX, y: existing.rect.maxY),
                    text: existing.text,
                    editingID: existing.id
                )
            } else {
                session.selectedAnnotationID = nil
                textDraft = EditorTextDraft(topLeft: point, text: "", editingID: nil)
            }
            dragContext = .ignored

        case .crop:
            session.selectedAnnotationID = nil
            dragContext = .crop(start: point)
            cropDraft = CGRect(origin: point, size: .zero)
        }
    }

    private func updateDrag(to point: CGPoint, constrained: Bool) {
        guard let dragContext else { return }

        switch dragContext {
        case let .move(annotationID, start, base):
            let delta = CGSize(width: point.x - start.x, height: point.y - start.y)
            var snapshot = base
            guard let index = snapshot.annotations.firstIndex(where: { $0.id == annotationID }) else { return }
            snapshot.annotations[index] = snapshot.annotations[index].moved(by: delta)
            draftSnapshot = snapshot

        case let .resize(handle, base):
            var snapshot = base
            guard let index = snapshot.annotations.firstIndex(where: { $0.id == handle.annotationID }) else { return }
            var target = point
            if constrained, snapshot.annotations[index].kind.isSegment {
                let anchor = handle.handle == .arrowStart
                    ? snapshot.annotations[index].endPoint
                    : snapshot.annotations[index].startPoint
                if let anchor {
                    target = AnnotationConstraint.snappedSegmentEnd(start: anchor, end: point)
                }
            }
            snapshot.annotations[index] = snapshot.annotations[index].resized(handle: handle.handle, to: target)
            draftSnapshot = snapshot

        case let .draw(tool, start, base):
            var snapshot = base
            if let annotation = makeShape(tool: tool, start: start, end: point, constrained: constrained) {
                snapshot.annotations.append(annotation)
            }
            draftSnapshot = snapshot

        case let .freehand(annotationID, _):
            guard var snapshot = draftSnapshot,
                  let index = snapshot.annotations.firstIndex(where: { $0.id == annotationID }) else { return }
            var annotation = snapshot.annotations[index]
            if let last = annotation.points.last, hypot(last.x - point.x, last.y - point.y) < 1.5 { return }
            annotation.points.append(point)
            annotation.rect = CGRect(enclosing: annotation.points)
            snapshot.annotations[index] = annotation
            draftSnapshot = snapshot

        case let .crop(start):
            cropDraft = constrained
                ? AnnotationConstraint.squareRect(start: start, end: point).intersection(visibleImageRect)
                : CGRect(segmentFrom: start, to: point)

        case .ignored:
            break
        }
    }

    private func finishDrag() {
        defer { dragContext = nil }
        guard let dragContext else { return }

        switch dragContext {
        case .crop:
            if let cropDraft, cropDraft.width >= 8, cropDraft.height >= 8 {
                var snapshot = session.currentSnapshot
                snapshot.cropRect = cropDraft.integral
                session.commit(snapshot: snapshot)
                tool = .select
            }
            cropDraft = nil

        case .draw:
            // A click without a drag leaves no zero-size mark behind.
            if let draft = draftSnapshot, let added = draft.annotations.last,
               draft.annotations.count > session.currentSnapshot.annotations.count {
                session.commit(snapshot: draft)
                session.selectedAnnotationID = added.id
            }
            draftSnapshot = nil

        case let .freehand(annotationID, _):
            if let draft = draftSnapshot {
                session.commit(snapshot: draft)
                session.selectedAnnotationID = annotationID
            }
            draftSnapshot = nil

        case .move, .resize:
            if let draftSnapshot, draftSnapshot != session.currentSnapshot {
                session.commit(snapshot: draftSnapshot)
            }
            draftSnapshot = nil

        case .ignored:
            break
        }
    }

    private func makeShape(tool: ScreenshotTool, start: CGPoint, end: CGPoint, constrained: Bool) -> ScreenshotAnnotation? {
        switch tool {
        case .arrow, .line:
            let target = constrained ? AnnotationConstraint.snappedSegmentEnd(start: start, end: end) : end
            guard hypot(target.x - start.x, target.y - start.y) >= 4 else { return nil }
            return tool == .arrow
                ? .arrow(start: start, end: target, style: style)
                : .line(start: start, end: target, style: style)
        case .rectangle, .ellipse, .redact:
            let rect = constrained
                ? AnnotationConstraint.squareRect(start: start, end: end)
                : CGRect(segmentFrom: start, to: end)
            guard rect.width >= 3, rect.height >= 3 else { return nil }
            switch tool {
            case .rectangle: return .rectangle(rect, style: style)
            case .ellipse: return .ellipse(rect, style: style)
            default: return .redact(rect, style: style)
            }
        default:
            return nil
        }
    }

    // MARK: - Keyboard

    private func handleKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if textDraft != nil {
            if event.keyCode == 53 {
                textDraft = nil
                return true
            }
            return false
        }

        if modifiers == [.command] {
            switch (event.keyCode, characters) {
            case (36, _), (76, _):
                commitPreviewIfNeeded()
                appState.copyActiveScreenshot()
                appState.requestEditorClose()
                return true
            case (_, "["):
                apply(size: activeSize.stepped(by: -1))
                return true
            case (_, "]"):
                apply(size: activeSize.stepped(by: 1))
                return true
            case (_, "d"):
                duplicateSelection()
                return true
            default:
                return false
            }
        }

        switch event.keyCode {
        case 53: // Escape
            if cropDraft != nil || session.selectedAnnotationID != nil {
                cropDraft = nil
                session.selectedAnnotationID = nil
                return true
            }
            return false
        case 51, 117: // Delete
            guard session.selectedAnnotationID != nil else { return false }
            session.deleteSelectedAnnotation()
            return true
        case 123, 124, 125, 126:
            guard modifiers.isSubset(of: [.shift, .function, .numericPad]),
                  session.selectedAnnotationID != nil else { return false }
            let step: CGFloat = modifiers.contains(.shift) ? 10 : 1
            let delta: CGSize
            switch event.keyCode {
            case 123: delta = CGSize(width: -step, height: 0)
            case 124: delta = CGSize(width: step, height: 0)
            case 125: delta = CGSize(width: 0, height: -step)
            default: delta = CGSize(width: 0, height: step)
            }
            session.updateSelectedAnnotation { $0 = $0.moved(by: delta) }
            return true
        default:
            break
        }

        if modifiers.isEmpty, let key = characters.first, characters.count == 1,
           let shortcutTool = ScreenshotTool.forShortcutKey(key) {
            tool = shortcutTool
            return true
        }
        return false
    }

    // MARK: - Actions

    private func apply(color: CodableColor) {
        if currentSelection != nil {
            session.updateSelectedAnnotation { $0.color = color }
        }
        var updated = style
        updated.color = color
        appState.updateEditorDefaultStyle(updated)
    }

    private func apply(size preset: AnnotationSizePreset) {
        if currentSelection != nil {
            session.updateSelectedAnnotation { annotation in
                annotation.lineWidth = preset.lineWidth
                annotation.fontSize = preset.fontSize
                switch annotation.kind {
                case .text:
                    annotation.rect.size = ScreenshotAnnotationRenderer.textSize(annotation.text, fontSize: preset.fontSize)
                case .counter:
                    let center = CGPoint(x: annotation.rect.midX, y: annotation.rect.midY)
                    let diameter = ScreenshotAnnotation.counterDiameter(fontSize: preset.fontSize)
                    annotation.rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
                default:
                    break
                }
            }
        }
        var updated = style
        updated.lineWidth = preset.lineWidth
        updated.fontSize = preset.fontSize
        appState.updateEditorDefaultStyle(updated)
    }

    private func duplicateSelection() {
        guard let selection = currentSelection else { return }
        var copy = selection.moved(by: CGSize(width: 16, height: -16))
        copy.id = UUID()
        if copy.kind == .counter {
            copy.number = session.nextCounterNumber
        }
        var snapshot = session.currentSnapshot
        snapshot.annotations.append(copy)
        session.commit(snapshot: snapshot)
        session.selectedAnnotationID = copy.id
    }

    private func commitTextIfNeeded() {
        guard let draft = textDraft else { return }
        textDraft = nil
        let text = draft.text

        var snapshot = session.currentSnapshot
        if let editingID = draft.editingID,
           let index = snapshot.annotations.firstIndex(where: { $0.id == editingID }) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                snapshot.annotations.remove(at: index)
                session.selectedAnnotationID = nil
            } else {
                snapshot.annotations[index].text = text
                snapshot.annotations[index].rect.size = ScreenshotAnnotationRenderer.textSize(
                    text,
                    fontSize: snapshot.annotations[index].fontSize
                )
            }
        } else {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let height = ScreenshotAnnotationRenderer.textSize(text, fontSize: style.fontSize).height
            let annotation = ScreenshotAnnotation.text(
                text,
                origin: CGPoint(x: draft.topLeft.x, y: draft.topLeft.y - height),
                style: style
            )
            snapshot.annotations.append(annotation)
            session.selectedAnnotationID = annotation.id
        }
        if snapshot != session.currentSnapshot {
            session.commit(snapshot: snapshot)
        }
    }

    private func commitPreviewIfNeeded() {
        commitTextIfNeeded()
        if let draftSnapshot, draftSnapshot != session.currentSnapshot {
            session.commit(snapshot: draftSnapshot)
        }
        draftSnapshot = nil
        dragContext = nil
        cropDraft = nil
    }

    private func makeDragItemProvider() -> NSItemProvider {
        guard let data = try? session.renderedPNGData() else { return NSItemProvider() }

        let baseName = session.draft.fileNameHint
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")
        let fileName = (baseName.isEmpty ? "Edison Screenshot" : baseName) + ".png"
        var fileURL: URL?
        do {
            let url = try TemporaryFiles.url(in: .dragOut, subfolder: session.id.uuidString, fileName: fileName)
            try data.write(to: url, options: .atomic)
            fileURL = url
        } catch {
            Log.capture.error("Editor drag-out write failed – \(error.localizedDescription)")
        }

        let provider = fileURL.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        provider.suggestedName = fileName
        return provider
    }

    // MARK: - Geometry helpers

    private func annotation(at point: CGPoint) -> ScreenshotAnnotation? {
        displayedSnapshot.annotations.reversed().first(where: { $0.contains(point) })
    }

    private func handle(at point: CGPoint) -> ScreenshotAnnotationHandle? {
        guard let selected = currentSelection else { return nil }
        let tolerance = max(8, 12 * visibleImageRect.width / 1000)
        return selected.handles().first(where: { hypot($0.point.x - point.x, $0.point.y - point.y) <= tolerance })
    }

    private func basePreviewImage() -> NSImage? {
        let rect = visibleImageRect
        guard let cropped = session.croppedBaseImage(to: rect) else { return nil }
        return NSImage(cgImage: cropped, size: rect.size)
    }

    private func fittedImageRect(in available: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: available)
        }

        // Never upscale small captures past 2× — they turn mushy.
        let scale = min(available.width / imageSize.width, available.height / imageSize.height, 2)
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
        let normalizedX = (point.x - visibleImageRect.minX) / visibleImageRect.width
        let normalizedY = (point.y - visibleImageRect.minY) / visibleImageRect.height
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

    private func resetTransientState() {
        tool = .arrow
        draftSnapshot = nil
        dragContext = nil
        cropDraft = nil
        textDraft = nil
    }
}

private struct EditorToolButton: View {
    let tool: ScreenshotTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 26)
                .foregroundStyle(isSelected ? Color.white : HubTheme.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? HubTheme.accentBrand : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(tool.rawValue) (\(String(tool.shortcutKey).uppercased()))")
        .accessibilityLabel(tool.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private enum EditorDragContext {
    case move(annotationID: UUID, start: CGPoint, base: ScreenshotDocumentSnapshot)
    case resize(handle: ScreenshotAnnotationHandle, base: ScreenshotDocumentSnapshot)
    case draw(tool: ScreenshotTool, start: CGPoint, base: ScreenshotDocumentSnapshot)
    case freehand(annotationID: UUID, base: ScreenshotDocumentSnapshot)
    case crop(start: CGPoint)
    case ignored
}

/// Routes editor key presses (tool letters, nudging, size steps) before the default responder chain.
private struct EditorKeyMonitor: NSViewRepresentable {
    let handler: (NSEvent) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.handler = handler
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.handler = handler
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        weak var view: NSView?
        var handler: ((NSEvent) -> Bool)?
        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      let window = self.view?.window,
                      event.window === window,
                      window.attachedSheet == nil else { return event }
                let isEditingText = window.firstResponder is NSTextView
                // While a text field has focus, only Escape is ours.
                if isEditingText, event.keyCode != 53 { return event }
                return (self.handler?(event) ?? false) ? nil : event
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        deinit { uninstall() }
    }
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

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
