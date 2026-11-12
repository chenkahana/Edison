import AppKit
import Combine
import CoreImage
import Foundation

enum ScreenshotTool: String, CaseIterable, Identifiable {
    case select = "Select"
    case arrow = "Arrow"
    case line = "Line"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case pen = "Pen"
    case highlighter = "Highlighter"
    case text = "Text"
    case counter = "Step Counter"
    case redact = "Pixelate"
    case crop = "Crop"

    var id: String { rawValue }

    /// Single-key shortcut, active whenever the editor is not editing text.
    var shortcutKey: Character {
        switch self {
        case .select: return "v"
        case .arrow: return "a"
        case .line: return "l"
        case .rectangle: return "r"
        case .ellipse: return "o"
        case .pen: return "p"
        case .highlighter: return "h"
        case .text: return "t"
        case .counter: return "n"
        case .redact: return "b"
        case .crop: return "c"
        }
    }

    var symbolName: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .pen: return "scribble"
        case .highlighter: return "highlighter"
        case .text: return "textformat"
        case .counter: return "1.circle"
        case .redact: return "checkerboard.rectangle"
        case .crop: return "crop"
        }
    }

    static func forShortcutKey(_ key: Character) -> ScreenshotTool? {
        allCases.first { $0.shortcutKey == key }
    }
}

/// Discrete size presets shared by stroke width and text size, so one control
/// scales every mark consistently (and ⌘[ / ⌘] can step through it).
enum AnnotationSizePreset: Int, CaseIterable, Identifiable {
    case small, medium, large, extraLarge

    var id: Int { rawValue }

    var lineWidth: Double {
        switch self {
        case .small: return 3
        case .medium: return 6
        case .large: return 10
        case .extraLarge: return 16
        }
    }

    var fontSize: Double {
        switch self {
        case .small: return 20
        case .medium: return 30
        case .large: return 44
        case .extraLarge: return 64
        }
    }

    var title: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .extraLarge: return "XL"
        }
    }

    static func nearest(toLineWidth lineWidth: Double) -> AnnotationSizePreset {
        allCases.min { abs($0.lineWidth - lineWidth) < abs($1.lineWidth - lineWidth) } ?? .medium
    }

    func stepped(by delta: Int) -> AnnotationSizePreset {
        AnnotationSizePreset(rawValue: max(0, min(Self.allCases.count - 1, rawValue + delta))) ?? self
    }
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
    case line
    case rectangle
    case ellipse
    case pen
    case highlighter
    case text
    case counter
    case redact

    /// Kinds whose geometry is a start/end segment.
    var isSegment: Bool { self == .arrow || self == .line }
    /// Kinds whose geometry is a freehand point list.
    var isFreehand: Bool { self == .pen || self == .highlighter }
}

struct ScreenshotAnnotation: Identifiable, Equatable {
    var id = UUID()
    var kind: ScreenshotAnnotationKind
    var rect: CGRect
    var startPoint: CGPoint?
    var endPoint: CGPoint?
    var points: [CGPoint]
    var text: String
    var number: Int
    var color: CodableColor
    var lineWidth: Double
    var fontSize: Double
    var blurRadius: Double

    init(
        kind: ScreenshotAnnotationKind,
        rect: CGRect,
        startPoint: CGPoint? = nil,
        endPoint: CGPoint? = nil,
        points: [CGPoint] = [],
        text: String = "",
        number: Int = 0,
        color: CodableColor = .systemRed,
        lineWidth: Double = 6,
        fontSize: Double = 34,
        blurRadius: Double = 18
    ) {
        self.kind = kind
        self.rect = rect.standardized
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.points = points
        self.text = text
        self.number = number
        self.color = color
        self.lineWidth = lineWidth
        self.fontSize = fontSize
        self.blurRadius = blurRadius
    }

    private init(kind: ScreenshotAnnotationKind, rect: CGRect, style: AnnotationStyleSettings) {
        self.init(
            kind: kind,
            rect: rect,
            color: style.color,
            lineWidth: style.lineWidth,
            fontSize: style.fontSize,
            blurRadius: style.blurRadius
        )
    }

    static func arrow(start: CGPoint, end: CGPoint, style: AnnotationStyleSettings) -> ScreenshotAnnotation {
        segment(.arrow, start: start, end: end, style: style)
    }

    static func line(start: CGPoint, end: CGPoint, style: AnnotationStyleSettings) -> ScreenshotAnnotation {
        segment(.line, start: start, end: end, style: style)
    }

    private static func segment(
        _ kind: ScreenshotAnnotationKind,
        start: CGPoint,
        end: CGPoint,
        style: AnnotationStyleSettings
    ) -> ScreenshotAnnotation {
        var annotation = ScreenshotAnnotation(kind: kind, rect: .zero, style: style)
        annotation.startPoint = start
        annotation.endPoint = end
        annotation.rect = CGRect(segmentFrom: start, to: end)
        return annotation
    }

    static func rectangle(_ rect: CGRect, style: AnnotationStyleSettings) -> ScreenshotAnnotation {
        ScreenshotAnnotation(kind: .rectangle, rect: rect, style: style)
    }

    static func ellipse(_ rect: CGRect, style: AnnotationStyleSettings) -> ScreenshotAnnotation {
        ScreenshotAnnotation(kind: .ellipse, rect: rect, style: style)
    }

    static func redact(_ rect: CGRect, style: AnnotationStyleSettings) -> ScreenshotAnnotation {
        ScreenshotAnnotation(kind: .redact, rect: rect, style: style)
    }

    static func freehand(
        _ kind: ScreenshotAnnotationKind,
        points: [CGPoint],
        style: AnnotationStyleSettings
    ) -> ScreenshotAnnotation {
        var annotation = ScreenshotAnnotation(kind: kind, rect: .zero, style: style)
        annotation.points = points
        annotation.rect = CGRect(enclosing: points)
        return annotation
    }

    static func counter(_ number: Int, center: CGPoint, style: AnnotationStyleSettings) -> ScreenshotAnnotation {
        let diameter = counterDiameter(fontSize: style.fontSize)
        var annotation = ScreenshotAnnotation(
            kind: .counter,
            rect: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter),
            style: style
        )
        annotation.number = number
        return annotation
    }

    static func counterDiameter(fontSize: Double) -> CGFloat {
        CGFloat(max(26, fontSize * 1.15))
    }

    static func text(
        _ text: String,
        origin: CGPoint,
        style: AnnotationStyleSettings
    ) -> ScreenshotAnnotation {
        var annotation = ScreenshotAnnotation(kind: .text, rect: .zero, style: style)
        annotation.text = text
        annotation.rect = CGRect(origin: origin, size: ScreenshotAnnotationRenderer.textSize(text, fontSize: style.fontSize))
        return annotation
    }

    /// The tightest rect that visually contains the mark, used for selection and hit-testing.
    var bounds: CGRect {
        switch kind {
        case .arrow, .line:
            guard let startPoint, let endPoint else { return rect }
            return CGRect(segmentFrom: startPoint, to: endPoint)
                .insetBy(dx: -max(lineWidth, 12), dy: -max(lineWidth, 12))
        case .pen, .highlighter:
            let inset = -max(ScreenshotAnnotationRenderer.strokeWidth(for: self) / 2, 6)
            return CGRect(enclosing: points).insetBy(dx: inset, dy: inset)
        case .rectangle, .ellipse, .text, .counter, .redact:
            return rect.standardized
        }
    }

    func handles() -> [ScreenshotAnnotationHandle] {
        switch kind {
        case .arrow, .line:
            guard let startPoint, let endPoint else { return [] }
            return [
                ScreenshotAnnotationHandle(annotationID: id, handle: .arrowStart, point: startPoint),
                ScreenshotAnnotationHandle(annotationID: id, handle: .arrowEnd, point: endPoint)
            ]
        case .pen, .highlighter, .counter:
            return []
        case .rectangle, .ellipse, .text, .redact:
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
        case .arrow, .line:
            guard let startPoint, let endPoint else { return false }
            return point.distanceToSegment(start: startPoint, end: endPoint) <= max(tolerance, CGFloat(lineWidth))
        case .pen, .highlighter:
            let reach = max(tolerance, ScreenshotAnnotationRenderer.strokeWidth(for: self) / 2)
            if points.count == 1, let only = points.first {
                return hypot(point.x - only.x, point.y - only.y) <= reach
            }
            return zip(points, points.dropFirst()).contains { point.distanceToSegment(start: $0, end: $1) <= reach }
        case .ellipse:
            let r = rect.standardized.insetBy(dx: -tolerance, dy: -tolerance)
            guard r.width > 0, r.height > 0 else { return false }
            let nx = (point.x - r.midX) / (r.width / 2)
            let ny = (point.y - r.midY) / (r.height / 2)
            return nx * nx + ny * ny <= 1
        case .rectangle, .text, .counter, .redact:
            return bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    func moved(by delta: CGSize) -> ScreenshotAnnotation {
        var copy = self
        copy.rect = rect.offsetBy(dx: delta.width, dy: delta.height)
        copy.startPoint = startPoint.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
        copy.endPoint = endPoint.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
        copy.points = points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
        return copy
    }

    func resized(handle: ScreenshotResizeHandle, to point: CGPoint) -> ScreenshotAnnotation {
        var copy = self

        switch (kind, handle) {
        case (.arrow, .arrowStart), (.line, .arrowStart):
            copy.startPoint = point
        case (.arrow, .arrowEnd), (.line, .arrowEnd):
            copy.endPoint = point
        case (.rectangle, _), (.ellipse, _), (.text, _), (.redact, _):
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
            if copy.kind == .text {
                copy.fontSize = max(14, min(120, ScreenshotAnnotationRenderer.fontSize(fittingHeight: bounds.height)))
                bounds.size = ScreenshotAnnotationRenderer.textSize(copy.text, fontSize: copy.fontSize)
            }
            copy.rect = bounds
        default:
            break
        }

        if copy.kind.isSegment, let startPoint = copy.startPoint, let endPoint = copy.endPoint {
            copy.rect = CGRect(segmentFrom: startPoint, to: endPoint)
        }

        return copy
    }
}

extension CGRect {
    init(segmentFrom start: CGPoint, to end: CGPoint) {
        self.init(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    init(enclosing points: [CGPoint]) {
        guard let first = points.first else {
            self = .zero
            return
        }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = Swift.min(minX, point.x)
            maxX = Swift.max(maxX, point.x)
            minY = Swift.min(minY, point.y)
            maxY = Swift.max(maxY, point.y)
        }
        self.init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

/// Shift-key constraints shared by every drawing tool.
enum AnnotationConstraint {
    /// Snaps the segment end so the angle is a multiple of 45°.
    static func snappedSegmentEnd(start: CGPoint, end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0 else { return end }
        let step = CGFloat.pi / 4
        let angle = (atan2(dy, dx) / step).rounded() * step
        return CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
    }

    /// Grows the drag rect into a square anchored at the start point.
    static func squareRect(start: CGPoint, end: CGPoint) -> CGRect {
        let side = max(abs(end.x - start.x), abs(end.y - start.y))
        let x = end.x >= start.x ? start.x : start.x - side
        let y = end.y >= start.y ? start.y : start.y - side
        return CGRect(x: x, y: y, width: side, height: side)
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

    private static let ciContext = CIContext()
    private var pixelatedCache: [Int: CGImage] = [:]

    private(set) lazy var baseImage: NSImage? = NSImage(data: draft.baseImageData)
    private(set) lazy var baseCGImage: CGImage? = baseImage?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    private(set) lazy var canvasSize: CGSize = baseImage?.size ?? .zero

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

    /// Next number for the step-counter tool.
    var nextCounterNumber: Int {
        (currentSnapshot.annotations.filter { $0.kind == .counter }.map(\.number).max() ?? 0) + 1
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

    // MARK: - Rendering

    /// The base image cropped to `rect` (image points, bottom-left origin).
    func croppedBaseImage(to rect: CGRect) -> CGImage? {
        guard let cgImage = baseCGImage else { return nil }
        let size = canvasSize
        guard size.width > 0, size.height > 0 else { return nil }
        let scaleX = CGFloat(cgImage.width) / size.width
        let scaleY = CGFloat(cgImage.height) / size.height
        // CGImage cropping uses a top-left origin; annotation space is bottom-left.
        let pixelRect = CGRect(
            x: rect.minX * scaleX,
            y: (size.height - rect.maxY) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral
        return cgImage.cropping(to: pixelRect)
    }

    /// The whole base image pixelated with `blockSize` points per block, cached per size.
    func pixelatedBaseImage(blockSize: Double) -> CGImage? {
        let key = max(4, Int(blockSize.rounded()))
        if let cached = pixelatedCache[key] { return cached }
        guard let cgImage = baseCGImage else { return nil }

        let pixelsPerPoint = CGFloat(cgImage.width) / max(canvasSize.width, 1)
        let input = CIImage(cgImage: cgImage)
        let output = input
            .clampedToExtent()
            .applyingFilter("CIPixellate", parameters: [
                kCIInputScaleKey: CGFloat(key) * pixelsPerPoint,
                kCIInputCenterKey: CIVector(x: 0, y: 0)
            ])
            .cropped(to: input.extent)
        guard let rendered = Self.ciContext.createCGImage(output, from: input.extent) else { return nil }
        pixelatedCache[key] = rendered
        return rendered
    }

    func drawAnnotations(
        _ annotations: [ScreenshotAnnotation],
        in context: CGContext,
        displayScale: CGFloat
    ) {
        ScreenshotAnnotationRenderer.draw(
            annotations,
            in: context,
            displayScale: displayScale,
            canvasSize: canvasSize,
            pixelatedSource: { [weak self] in self?.pixelatedBaseImage(blockSize: $0) }
        )
    }

    func renderedPNGData() throws -> Data {
        guard let cgImage = renderedCGImage() else {
            throw CocoaError(.fileWriteUnknown)
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        // Keep the point size so Retina captures paste at their on-screen size.
        rep.size = visibleImageRect.standardized.size
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    func renderedImage() -> NSImage? {
        guard let cgImage = renderedCGImage() else { return nil }
        return NSImage(cgImage: cgImage, size: visibleImageRect.standardized.size)
    }

    func renderedCGImage() -> CGImage? {
        let visibleRect = visibleImageRect.standardized
        guard visibleRect.width > 0, visibleRect.height > 0,
              let cropped = croppedBaseImage(to: visibleRect) else { return nil }

        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let preferredSpace = cropped.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? sRGB
        guard let context = CGContext(
            data: nil,
            width: cropped.width,
            height: cropped.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: preferredSpace,
            bitmapInfo: bitmapInfo
        ) ?? CGContext(
            data: nil,
            width: cropped.width,
            height: cropped.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: sRGB,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
        let scaleX = CGFloat(cropped.width) / visibleRect.width
        let scaleY = CGFloat(cropped.height) / visibleRect.height
        context.scaleBy(x: scaleX, y: scaleY)
        context.translateBy(x: -visibleRect.minX, y: -visibleRect.minY)
        drawAnnotations(currentSnapshot.annotations, in: context, displayScale: scaleX)
        return context.makeImage()
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
