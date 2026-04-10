import AppKit
import SwiftUI

private enum EditorTool: String, CaseIterable, Identifiable {
    case crop = "Crop"
    case arrow = "Arrow"
    case rectangle = "Rectangle"
    case text = "Text"

    var id: String { rawValue }
}

struct EditorWindowView: View {
    let imageData: Data?
    let onClose: () -> Void

    @State private var tool: EditorTool = .arrow
    @State private var history: [NSImage] = []
    @State private var historyIndex = 0

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    @State private var pendingText = ""
    @State private var textInsertionPoint: CGPoint?

    private let accentColor = NSColor.systemRed

    private var currentImage: NSImage? {
        guard history.indices.contains(historyIndex) else { return nil }
        return history[historyIndex]
    }

    private var canUndo: Bool { historyIndex > 0 }
    private var canRedo: Bool { historyIndex < history.count - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            topBar

            if let image = currentImage {
                editorCanvas(image: image)
            } else {
                ContentUnavailableView("No Screenshot", systemImage: "photo")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .onAppear {
            initializeImageIfNeeded()
        }
        .onChange(of: imageData) { _, _ in
            initializeImageIfNeeded(force: true)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Text("Screenshot Editor")
                .font(.headline)

            Picker("Tool", selection: $tool) {
                ForEach(EditorTool.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            Button("Undo") { undo() }
                .disabled(!canUndo)

            Button("Redo") { redo() }
                .disabled(!canRedo)

            Button("Copy") { copyToClipboard() }
                .disabled(currentImage == nil)

            Button("Save") { saveToFile() }
                .disabled(currentImage == nil)

            Spacer()

            Button("Done") { onClose() }
        }
    }

    private func editorCanvas(image: NSImage) -> some View {
        GeometryReader { proxy in
            let frame = fittedImageRect(in: proxy.size, imageSize: image.size)

            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.06)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Image(nsImage: image)
                    .resizable()
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)

                if let overlayPath = dragPreviewPath(displayRect: frame, imageSize: image.size) {
                    overlayPath
                        .stroke(Color(accentColor), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }

                if tool == .text, let point = textInsertionPoint {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Text", text: $pendingText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
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
                    .padding(8)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .position(
                        x: toDisplayPoint(point, displayRect: frame, imageSize: image.size).x + 120,
                        y: toDisplayPoint(point, displayRect: frame, imageSize: image.size).y + 40
                    )
                }

                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(displayRect: frame, imageSize: image.size))
            }
        }
    }

    private func dragGesture(displayRect: CGRect, imageSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard pointInsideImage(value.location, displayRect: displayRect) else { return }
                let imagePoint = toImagePoint(value.location, displayRect: displayRect, imageSize: imageSize)

                if dragStart == nil {
                    dragStart = imagePoint
                    dragCurrent = imagePoint

                    if tool == .text {
                        textInsertionPoint = imagePoint
                        pendingText = ""
                    }
                } else {
                    dragCurrent = imagePoint
                }
            }
            .onEnded { value in
                defer {
                    if tool != .text {
                        dragStart = nil
                        dragCurrent = nil
                    }
                }

                guard tool != .text else { return }
                guard pointInsideImage(value.location, displayRect: displayRect) else { return }
                guard let start = dragStart else { return }
                let end = toImagePoint(value.location, displayRect: displayRect, imageSize: imageSize)
                applyToolAction(from: start, to: end)
            }
    }

    private func dragPreviewPath(displayRect: CGRect, imageSize: CGSize) -> Path? {
        guard let start = dragStart, let end = dragCurrent else { return nil }

        let startDisplay = toDisplayPoint(start, displayRect: displayRect, imageSize: imageSize)
        let endDisplay = toDisplayPoint(end, displayRect: displayRect, imageSize: imageSize)

        switch tool {
        case .crop, .rectangle:
            let rect = normalizedRect(start: startDisplay, end: endDisplay)
            return Path { path in
                path.addRect(rect)
            }
        case .arrow:
            return Path { path in
                path.move(to: startDisplay)
                path.addLine(to: endDisplay)
            }
        case .text:
            return nil
        }
    }

    private func applyToolAction(from start: CGPoint, to end: CGPoint) {
        guard let image = currentImage else { return }

        let result: NSImage?
        switch tool {
        case .crop:
            result = crop(image: image, start: start, end: end)
        case .rectangle:
            result = drawRectangle(image: image, start: start, end: end)
        case .arrow:
            result = drawArrow(image: image, start: start, end: end)
        case .text:
            result = nil
        }

        if let result {
            pushHistory(result)
        }
    }

    private func commitText(at point: CGPoint) {
        guard let image = currentImage else { return }
        let trimmed = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            textInsertionPoint = nil
            return
        }

        if let result = drawText(image: image, text: trimmed, at: point) {
            pushHistory(result)
        }

        pendingText = ""
        textInsertionPoint = nil
        dragStart = nil
        dragCurrent = nil
    }

    private func initializeImageIfNeeded(force: Bool = false) {
        guard let imageData, let image = NSImage(data: imageData) else { return }
        if !history.isEmpty && !force { return }

        history = [image]
        historyIndex = 0
        dragStart = nil
        dragCurrent = nil
        pendingText = ""
        textInsertionPoint = nil
    }

    private func pushHistory(_ image: NSImage) {
        var next = Array(history.prefix(historyIndex + 1))
        next.append(image)
        if next.count > 50 {
            next.removeFirst(next.count - 50)
        }
        history = next
        historyIndex = history.count - 1
    }

    private func undo() {
        guard canUndo else { return }
        historyIndex -= 1
    }

    private func redo() {
        guard canRedo else { return }
        historyIndex += 1
    }

    private func copyToClipboard() {
        guard let image = currentImage, let png = image.pngData() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
    }

    private func saveToFile() {
        guard let image = currentImage, let png = image.pngData() else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "edited-screenshot.png"
        panel.allowedContentTypes = [.png]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? png.write(to: url, options: .atomic)
    }

    private func drawRectangle(image: NSImage, start: CGPoint, end: CGPoint) -> NSImage? {
        guard let output = image.cloned() else { return nil }
        let rect = normalizedRect(start: start, end: end)
        guard rect.width > 2, rect.height > 2 else { return output }

        output.lockFocus()
        accentColor.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 6
        path.stroke()
        output.unlockFocus()
        return output
    }

    private func drawArrow(image: NSImage, start: CGPoint, end: CGPoint) -> NSImage? {
        guard let output = image.cloned() else { return nil }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 4 else { return output }

        let ux = dx / length
        let uy = dy / length
        let headLength: CGFloat = min(30, max(12, length * 0.2))
        let headWidth: CGFloat = headLength * 0.7

        let baseX = end.x - ux * headLength
        let baseY = end.y - uy * headLength
        let perpX = -uy
        let perpY = ux

        let left = CGPoint(x: baseX + perpX * headWidth * 0.5, y: baseY + perpY * headWidth * 0.5)
        let right = CGPoint(x: baseX - perpX * headWidth * 0.5, y: baseY - perpY * headWidth * 0.5)

        output.lockFocus()
        accentColor.setStroke()
        accentColor.setFill()

        let shaft = NSBezierPath()
        shaft.move(to: start)
        shaft.line(to: CGPoint(x: baseX, y: baseY))
        shaft.lineWidth = 6
        shaft.lineCapStyle = .round
        shaft.stroke()

        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: left)
        head.line(to: right)
        head.close()
        head.fill()

        output.unlockFocus()
        return output
    }

    private func drawText(image: NSImage, text: String, at point: CGPoint) -> NSImage? {
        guard let output = image.cloned() else { return nil }

        output.lockFocus()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 34, weight: .semibold),
            .foregroundColor: accentColor
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        attributed.draw(at: point)
        output.unlockFocus()
        return output
    }

    private func crop(image: NSImage, start: CGPoint, end: CGPoint) -> NSImage? {
        let rect = normalizedRect(start: start, end: end)
        guard rect.width > 2, rect.height > 2 else { return nil }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let scaleX = CGFloat(cgImage.width) / image.size.width
        let scaleY = CGFloat(cgImage.height) / image.size.height
        let scaledRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral

        guard let cropped = cgImage.cropping(to: scaledRect) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: scaledRect.width / scaleX, height: scaledRect.height / scaleY))
    }

    private func pointInsideImage(_ location: CGPoint, displayRect: CGRect) -> Bool {
        displayRect.contains(location)
    }

    private func toImagePoint(_ location: CGPoint, displayRect: CGRect, imageSize: CGSize) -> CGPoint {
        guard displayRect.width > 0, displayRect.height > 0 else { return .zero }

        let normalizedX = ((location.x - displayRect.minX) / displayRect.width).clamped(to: 0...1)
        let normalizedY = ((location.y - displayRect.minY) / displayRect.height).clamped(to: 0...1)
        let imageX = normalizedX * imageSize.width
        let imageY = (1 - normalizedY) * imageSize.height
        return CGPoint(x: imageX, y: imageY)
    }

    private func toDisplayPoint(_ point: CGPoint, displayRect: CGRect, imageSize: CGSize) -> CGPoint {
        guard imageSize.width > 0, imageSize.height > 0 else { return displayRect.origin }

        let normalizedX = (point.x / imageSize.width).clamped(to: 0...1)
        let normalizedY = (point.y / imageSize.height).clamped(to: 0...1)
        let displayX = displayRect.minX + (normalizedX * displayRect.width)
        let displayY = displayRect.minY + ((1 - normalizedY) * displayRect.height)
        return CGPoint(x: displayX, y: displayY)
    }

    private func normalizedRect(start: CGPoint, end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
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
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension NSImage {
    func cloned() -> NSImage? {
        guard let data = tiffRepresentation else { return nil }
        return NSImage(data: data)
    }

    func pngData() -> Data? {
        guard
            let tiffData = tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}
