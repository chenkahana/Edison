import AppKit
import Combine
import CoreImage
import Foundation

enum ScreenshotTool: String, CaseIterable, Identifiable {
    case select = "Select"
    case arrow = "Arrow"
    case rectangle = "Rectangle"
    case text = "Text"
    case redact = "Blur/Redact"
    case crop = "Crop"

    var id: String { rawValue }
}

struct ScreenshotDraft: Identifiable {
    let id: UUID
    let baseImageData: Data
    let fileNameHint: String
    let captureDisplayID: CGDirectDisplayID?
    let captureRect: CGRect?

    init(
        id: UUID = UUID(),
        baseImageData: Data,
        fileNameHint: String,
        captureDisplayID: CGDirectDisplayID? = nil,
        captureRect: CGRect? = nil
    ) {
        self.id = id
        self.baseImageData = baseImageData
        self.fileNameHint = fileNameHint
        self.captureDisplayID = captureDisplayID
        self.captureRect = captureRect
    }
}

enum ScreenshotResizeHandle: Hashable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case arrowStart
    case arrowEnd
}

struct ScreenshotAnnotationHandle: Hashable {
    var annotationID: UUID
    var handle: ScreenshotResizeHandle
    var point: CGPoint

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.annotationID == rhs.annotationID
            && lhs.handle == rhs.handle
            && lhs.point.x == rhs.point.x
            && lhs.point.y == rhs.point.y
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(annotationID)
        hasher.combine(handle)
        hasher.combine(point.x)
        hasher.combine(point.y)
    }
}

enum ScreenshotAnnotationKind: String, Hashable {
    case arrow
    case rectangle
    case text
    case redact
}

struct ScreenshotAnnotation: Identifiable, Equatable {
    var id = UUID()
    var kind: ScreenshotAnnotationKind
    var rect: CGRect
    var startPoint: CGPoint?
    var endPoint: CGPoint?
    var text: String
    var color: CodableColor
    var lineWidth: Double
    var fontSize: Double
    var blurRadius: Double

    init(
        kind: ScreenshotAnnotationKind,
        rect: CGRect,
        startPoint: CGPoint? = nil,
        endPoint: CGPoint? = nil,
        text: String = "",
        color: CodableColor = .systemRed,
        lineWidth: Double = 6,
        fontSize: Double = 34,
        blurRadius: Double = 18
    ) {
        self.kind = kind
        self.rect = rect.standardized
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.text = text
        self.color = color
        self.lineWidth = lineWidth
        self.fontSize = fontSize
        self.blurRadius = blurRadius
    }

    static func arrow(
        start: CGPoint,
        end: CGPoint,
        style: AnnotationStyleSettings
    ) -> ScreenshotAnnotation {
        ScreenshotAnnotation(
            kind: .arrow,
            rect: CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ),
            startPoint: start,
            endPoint: end,
            color: style.color,
            lineWidth: style.lineWidth,
            fontSize: style.fontSize,
            blurRadius: style.blurRadius
        )
    }

    static func rectangle(_ rect: CGRect, style: AnnotationStyleSettings) -> ScreenshotAnnotation {
        ScreenshotAnnotation(
            kind: .rectangle,
            rect: rect,
            color: style.color,
            lineWidth: style.lineWidth,
            fontSize: style.fontSize,
            blurRadius: style.blurRadius
        )
    }

    static func redact(_ rect: CGRect, style: AnnotationStyleSettings) -> ScreenshotAnnotation {
        ScreenshotAnnotation(
            kind: .redact,
            rect: rect,
            color: style.color,
            lineWidth: style.lineWidth,
            fontSize: style.fontSize,
            blurRadius: style.blurRadius
        )
    }

    static func text(
        _ text: String,
        origin: CGPoint,
        style: AnnotationStyleSettings
    ) -> ScreenshotAnnotation {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: style.fontSize, weight: .semibold)
        ]
        let textSize = NSAttributedString(string: text, attributes: attributes).size()
        let rect = CGRect(origin: origin, size: CGSize(width: max(textSize.width, 40), height: max(textSize.height, style.fontSize + 12)))
        return ScreenshotAnnotation(
            kind: .text,
            rect: rect,
            text: text,
            color: style.color,
            lineWidth: style.lineWidth,
            fontSize: style.fontSize,
            blurRadius: style.blurRadius
        )
    }

    var bounds: CGRect {
        switch kind {
        case .arrow:
            guard let startPoint, let endPoint else { return rect }
            return CGRect(
                x: min(startPoint.x, endPoint.x),
                y: min(startPoint.y, endPoint.y),
                width: abs(endPoint.x - startPoint.x),
                height: abs(endPoint.y - startPoint.y)
            ).insetBy(dx: -max(lineWidth, 12), dy: -max(lineWidth, 12))
        case .rectangle, .text, .redact:
            return rect.standardized
        }
    }

    func handles() -> [ScreenshotAnnotationHandle] {
        switch kind {
        case .arrow:
            guard let startPoint, let endPoint else { return [] }
            return [
                ScreenshotAnnotationHandle(annotationID: id, handle: .arrowStart, point: startPoint),
                ScreenshotAnnotationHandle(annotationID: id, handle: .arrowEnd, point: endPoint)
            ]
        case .rectangle, .text, .redact:
            let bounds = rect.standardized
            return [
                ScreenshotAnnotationHandle(annotationID: id, handle: .topLeading, point: CGPoint(x: bounds.minX, y: bounds.maxY)),
                ScreenshotAnnotationHandle(annotationID: id, handle: .topTrailing, point: CGPoint(x: bounds.maxX, y: bounds.maxY)),
                ScreenshotAnnotationHandle(annotationID: id, handle: .bottomLeading, point: CGPoint(x: bounds.minX, y: bounds.minY)),
                ScreenshotAnnotationHandle(annotationID: id, handle: .bottomTrailing, point: CGPoint(x: bounds.maxX, y: bounds.minY))
            ]
        }
    }

    func contains(_ point: CGPoint, tolerance: CGFloat = 10) -> Bool {
        switch kind {
        case .arrow:
            guard let startPoint, let endPoint else { return false }
            return point.distanceToSegment(start: startPoint, end: endPoint) <= max(tolerance, CGFloat(lineWidth))
        case .rectangle, .text, .redact:
            return bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    func moved(by delta: CGSize) -> ScreenshotAnnotation {
        var copy = self
        copy.rect = rect.offsetBy(dx: delta.width, dy: delta.height)
        copy.startPoint = startPoint.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
        copy.endPoint = endPoint.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
        return copy
    }

    func resized(handle: ScreenshotResizeHandle, to point: CGPoint) -> ScreenshotAnnotation {
        var copy = self

        switch (kind, handle) {
        case (.arrow, .arrowStart):
            copy.startPoint = point
        case (.arrow, .arrowEnd):
            copy.endPoint = point
        case (.rectangle, _), (.text, _), (.redact, _):
            var bounds = rect.standardized
            switch handle {
            case .topLeading:
                bounds = CGRect(x: point.x, y: bounds.minY, width: bounds.maxX - point.x, height: point.y - bounds.minY)
            case .topTrailing:
                bounds = CGRect(x: bounds.minX, y: bounds.minY, width: point.x - bounds.minX, height: point.y - bounds.minY)
            case .bottomLeading:
                bounds = CGRect(x: point.x, y: point.y, width: bounds.maxX - point.x, height: bounds.maxY - point.y)
            case .bottomTrailing:
                bounds = CGRect(x: bounds.minX, y: point.y, width: point.x - bounds.minX, height: bounds.maxY - point.y)
            case .arrowStart, .arrowEnd:
                break
            }
            bounds = bounds.standardized
            bounds.size.width = max(bounds.width, 20)
            bounds.size.height = max(bounds.height, 20)
            copy.rect = bounds
            if copy.kind == .text {
                copy.fontSize = max(14, min(96, Double(bounds.height * 0.8)))
            }
        case (.arrow, .topLeading), (.arrow, .topTrailing), (.arrow, .bottomLeading), (.arrow, .bottomTrailing):
            break
        }

        if let startPoint = copy.startPoint, let endPoint = copy.endPoint {
            copy.rect = CGRect(
                x: min(startPoint.x, endPoint.x),
                y: min(startPoint.y, endPoint.y),
                width: abs(endPoint.x - startPoint.x),
                height: abs(endPoint.y - startPoint.y)
            )
        }

        return copy
    }
}

struct ScreenshotDocumentSnapshot: Equatable {
    var cropRect: CGRect?
    var annotations: [ScreenshotAnnotation]

    static let empty = ScreenshotDocumentSnapshot(cropRect: nil, annotations: [])
}

@MainActor
final class ScreenshotSession: ObservableObject, Identifiable {
    let id: UUID
    let draft: ScreenshotDraft

    @Published private(set) var history: [ScreenshotDocumentSnapshot]
    @Published private(set) var historyIndex: Int
    @Published var selectedAnnotationID: UUID?
    @Published private(set) var committedItemID: UUID?

    private var committedSnapshot: ScreenshotDocumentSnapshot?

    init(
        draft: ScreenshotDraft,
        initialSnapshot: ScreenshotDocumentSnapshot = .empty,
        committedItemID: UUID? = nil,
        committedSnapshot: ScreenshotDocumentSnapshot? = nil
    ) {
        self.id = draft.id
        self.draft = draft
        self.history = [initialSnapshot]
        self.historyIndex = 0
        self.committedItemID = committedItemID
        self.committedSnapshot = committedSnapshot
    }

    var currentSnapshot: ScreenshotDocumentSnapshot {
        history[historyIndex]
    }

    var baseImage: NSImage? {
        NSImage(data: draft.baseImageData)
    }

    var canvasSize: CGSize {
        baseImage?.size ?? .zero
    }

    var visibleImageRect: CGRect {
        currentSnapshot.cropRect ?? CGRect(origin: .zero, size: canvasSize)
    }

    var canUndo: Bool { historyIndex > 0 }
    var canRedo: Bool { historyIndex < history.count - 1 }
    var hasCommittedHistoryItem: Bool { committedItemID != nil }

    var hasUnsavedChanges: Bool {
        if let committedSnapshot {
            return committedSnapshot != currentSnapshot
        }
        return currentSnapshot != .empty || committedItemID == nil
    }

    func commit(snapshot: ScreenshotDocumentSnapshot) {
        var next = Array(history.prefix(historyIndex + 1))
        next.append(snapshot)
        if next.count > 100 {
            next.removeFirst(next.count - 100)
        }
        history = next
        historyIndex = history.count - 1
    }

    func undo() {
        guard canUndo else { return }
        historyIndex -= 1
        if !currentSnapshot.annotations.contains(where: { $0.id == selectedAnnotationID }) {
            selectedAnnotationID = nil
        }
    }

    func redo() {
        guard canRedo else { return }
        historyIndex += 1
        if !currentSnapshot.annotations.contains(where: { $0.id == selectedAnnotationID }) {
            selectedAnnotationID = nil
        }
    }

    func deleteSelectedAnnotation() {
        guard let selectedAnnotationID else { return }
        var snapshot = currentSnapshot
        snapshot.annotations.removeAll { $0.id == selectedAnnotationID }
        self.selectedAnnotationID = nil
        commit(snapshot: snapshot)
    }

    func updateSelectedAnnotation(_ mutate: (inout ScreenshotAnnotation) -> Void) {
        guard let selectedAnnotationID else { return }
        var snapshot = currentSnapshot
        guard let index = snapshot.annotations.firstIndex(where: { $0.id == selectedAnnotationID }) else { return }
        mutate(&snapshot.annotations[index])
        commit(snapshot: snapshot)
    }

    func recordCommit(itemID: UUID?) {
        committedItemID = itemID
        committedSnapshot = currentSnapshot
    }

    func duplicateForEditing() -> ScreenshotSession {
        ScreenshotSession(
            draft: draft,
            initialSnapshot: currentSnapshot,
            committedItemID: committedItemID,
            committedSnapshot: committedSnapshot
        )
    }

    func renderedPNGData() throws -> Data {
        guard let image = renderedImage(), let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    func renderedImage() -> NSImage? {
        guard let baseImage, let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let visibleRect = visibleImageRect.standardized
        guard visibleRect.width > 0, visibleRect.height > 0 else { return nil }

        let scaleX = CGFloat(cgImage.width) / baseImage.size.width
        let scaleY = CGFloat(cgImage.height) / baseImage.size.height
        let scaledRect = CGRect(
            x: visibleRect.origin.x * scaleX,
            y: visibleRect.origin.y * scaleY,
            width: visibleRect.width * scaleX,
            height: visibleRect.height * scaleY
        ).integral

        guard let cropped = cgImage.cropping(to: scaledRect) else { return nil }
        let outputSize = CGSize(width: scaledRect.width / scaleX, height: scaledRect.height / scaleY)

        let ciContext = CIContext()
        var ciImage = CIImage(cgImage: cropped)
        let outputRect = CGRect(origin: .zero, size: outputSize)

        for annotation in currentSnapshot.annotations where annotation.kind == .redact {
            let localRect = annotation.rect.offsetBy(dx: -visibleRect.minX, dy: -visibleRect.minY).intersection(outputRect)
            guard !localRect.isEmpty else { continue }
            let clamped = localRect.integral
            let blurred = ciImage
                .cropped(to: clamped)
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: annotation.blurRadius])
                .cropped(to: clamped)
            ciImage = blurred.composited(over: ciImage)
        }

        guard let processed = ciContext.createCGImage(ciImage, from: outputRect) else { return nil }
        let output = NSImage(cgImage: processed, size: outputSize)

        output.lockFocus()
        for annotation in currentSnapshot.annotations where annotation.kind != .redact {
            draw(annotation: annotation, visibleRect: visibleRect)
        }
        output.unlockFocus()

        return output
    }

    private func draw(annotation: ScreenshotAnnotation, visibleRect: CGRect) {
        switch annotation.kind {
        case .rectangle:
            let rect = annotation.rect.offsetBy(dx: -visibleRect.minX, dy: -visibleRect.minY)
            annotation.color.nsColor.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = CGFloat(annotation.lineWidth)
            path.stroke()

        case .arrow:
            guard let startPoint = annotation.startPoint, let endPoint = annotation.endPoint else { return }
            drawArrow(
                start: CGPoint(x: startPoint.x - visibleRect.minX, y: startPoint.y - visibleRect.minY),
                end: CGPoint(x: endPoint.x - visibleRect.minX, y: endPoint.y - visibleRect.minY),
                color: annotation.color.nsColor,
                lineWidth: CGFloat(annotation.lineWidth)
            )

        case .text:
            let point = CGPoint(x: annotation.rect.minX - visibleRect.minX, y: annotation.rect.minY - visibleRect.minY)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold),
                .foregroundColor: annotation.color.nsColor
            ]
            NSAttributedString(string: annotation.text, attributes: attributes).draw(at: point)

        case .redact:
            break
        }
    }

    private func drawArrow(start: CGPoint, end: CGPoint, color: NSColor, lineWidth: CGFloat) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 4 else { return }

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

        color.setStroke()
        color.setFill()

        let shaft = NSBezierPath()
        shaft.move(to: start)
        shaft.line(to: CGPoint(x: baseX, y: baseY))
        shaft.lineWidth = lineWidth
        shaft.lineCapStyle = .round
        shaft.stroke()

        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: left)
        head.line(to: right)
        head.close()
        head.fill()
    }
}

private extension NSImage {
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

private extension CGPoint {
    func distanceToSegment(start: CGPoint, end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        if dx == 0, dy == 0 {
            return hypot(x - start.x, y - start.y)
        }

        let projection = ((x - start.x) * dx + (y - start.y) * dy) / (dx * dx + dy * dy)
        let clamped = min(max(projection, 0), 1)
        let projected = CGPoint(x: start.x + clamped * dx, y: start.y + clamped * dy)
        return hypot(x - projected.x, y - projected.y)
    }
}
