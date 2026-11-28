import Foundation
import CoreGraphics

#if canImport(Testing)
import Testing
@testable import Edison

/// Editor model logic: tool keys, size presets, annotation geometry and hit-testing, shift constraints,
/// and the session's undo/redo history. Nothing here renders pixels.
@MainActor
struct ScreenshotDocumentTests {
    private let style = AnnotationStyleSettings.default

    private func session() -> ScreenshotSession {
        ScreenshotSession(draft: ScreenshotDraft(baseImageData: Data(), fileNameHint: "test"))
    }

    private func box(_ x: Double = 0, _ y: Double = 0, _ size: Double = 100) -> ScreenshotAnnotation {
        .rectangle(CGRect(x: x, y: y, width: size, height: size), style: style)
    }

    private func snapshot(_ annotations: ScreenshotAnnotation...) -> ScreenshotDocumentSnapshot {
        ScreenshotDocumentSnapshot(cropRect: nil, annotations: annotations)
    }

    // MARK: Tools and presets

    @Test("Every tool has its own shortcut key, and each key finds its tool")
    func toolShortcuts() {
        let keys = ScreenshotTool.allCases.map(\.shortcutKey)
        #expect(Set(keys).count == keys.count)
        for tool in ScreenshotTool.allCases {
            #expect(ScreenshotTool.forShortcutKey(tool.shortcutKey) == tool)
        }
        #expect(ScreenshotTool.forShortcutKey("z") == nil)
    }

    @Test("Size presets pick the nearest width and step within bounds")
    func presets() {
        #expect(AnnotationSizePreset.nearest(toLineWidth: 7) == .medium)
        #expect(AnnotationSizePreset.nearest(toLineWidth: 0) == .small)
        #expect(AnnotationSizePreset.nearest(toLineWidth: 100) == .extraLarge)
        #expect(AnnotationSizePreset.medium.stepped(by: 1) == .large)
        #expect(AnnotationSizePreset.extraLarge.stepped(by: 1) == .extraLarge)
        #expect(AnnotationSizePreset.small.stepped(by: -1) == .small)
        #expect(AnnotationSizePreset.small.stepped(by: 10) == .extraLarge)
    }

    // MARK: Geometry

    @Test("A rectangle drawn backwards is stored with positive size")
    func standardizedRect() {
        let annotation = ScreenshotAnnotation.rectangle(CGRect(x: 100, y: 100, width: -100, height: -100), style: style)
        #expect(annotation.rect == CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    @Test("Segment annotations store their span and pad their bounds")
    func segmentBounds() {
        let arrow = ScreenshotAnnotation.arrow(start: CGPoint(x: 100, y: 50), end: CGPoint(x: 0, y: 0), style: style)
        #expect(arrow.rect == CGRect(x: 0, y: 0, width: 100, height: 50))
        #expect(arrow.bounds == CGRect(x: -12, y: -12, width: 124, height: 74))
        #expect(arrow.handles().map(\.handle) == [.arrowStart, .arrowEnd])
    }

    @Test("Freehand marks enclose their points; an empty one is zero")
    func freehandRect() {
        let pen = ScreenshotAnnotation.freehand(.pen, points: [CGPoint(x: 5, y: 10), CGPoint(x: 25, y: 4), CGPoint(x: 15, y: 30)], style: style)
        #expect(pen.rect == CGRect(x: 5, y: 4, width: 20, height: 26))
        #expect(CGRect(enclosing: []) == .zero)
        #expect(pen.handles().isEmpty)
    }

    @Test("A step counter is centred on the click and never smaller than 26 points")
    func counterGeometry() {
        let counter = ScreenshotAnnotation.counter(3, center: CGPoint(x: 100, y: 100), style: style)
        #expect(counter.number == 3)
        #expect(abs(counter.rect.midX - 100) < 0.001)
        #expect(abs(counter.rect.midY - 100) < 0.001)
        #expect(ScreenshotAnnotation.counterDiameter(fontSize: 10) == 26)
        #expect(abs(ScreenshotAnnotation.counterDiameter(fontSize: 100) - 115) < 0.001)
    }

    @Test("Rectangle hit-testing allows a 10 point tolerance")
    func rectangleHits() {
        let annotation = box()
        #expect(annotation.contains(CGPoint(x: 50, y: 50)))
        #expect(annotation.contains(CGPoint(x: 105, y: 50)))
        #expect(!annotation.contains(CGPoint(x: 115, y: 50)))
    }

    @Test("Ellipse hit-testing follows the curve, not the bounding box")
    func ellipseHits() {
        let ellipse = ScreenshotAnnotation.ellipse(CGRect(x: 0, y: 0, width: 100, height: 100), style: style)
        #expect(ellipse.contains(CGPoint(x: 50, y: 50)))
        #expect(ellipse.contains(CGPoint(x: 50, y: 105)))
        #expect(!ellipse.contains(CGPoint(x: 0, y: 0)))
    }

    @Test("Line hit-testing measures distance to the segment")
    func lineHits() {
        let line = ScreenshotAnnotation.line(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 100, y: 0), style: style)
        #expect(line.contains(CGPoint(x: 50, y: 9)))
        #expect(!line.contains(CGPoint(x: 50, y: 11)))
        #expect(line.contains(CGPoint(x: -5, y: 0)))
        #expect(!line.contains(CGPoint(x: -20, y: 0)))
    }

    @Test("Moving shifts the rect, segment ends and freehand points together")
    func moving() {
        let delta = CGSize(width: 10, height: -5)
        #expect(box().moved(by: delta).rect == CGRect(x: 10, y: -5, width: 100, height: 100))

        let arrow = ScreenshotAnnotation.arrow(start: .zero, end: CGPoint(x: 20, y: 20), style: style).moved(by: delta)
        #expect(arrow.startPoint == CGPoint(x: 10, y: -5))
        #expect(arrow.endPoint == CGPoint(x: 30, y: 15))

        let pen = ScreenshotAnnotation.freehand(.pen, points: [.zero, CGPoint(x: 4, y: 4)], style: style).moved(by: delta)
        #expect(pen.points == [CGPoint(x: 10, y: -5), CGPoint(x: 14, y: -1)])
        #expect(pen.id == pen.moved(by: .zero).id)
    }

    @Test("Resizing by a corner moves that corner and keeps the opposite one fixed")
    func resizing() {
        let grown = box().resized(handle: .bottomTrailing, to: CGPoint(x: 150, y: -20))
        #expect(grown.rect == CGRect(x: 0, y: -20, width: 150, height: 120))

        let shrunk = box().resized(handle: .topTrailing, to: CGPoint(x: 5, y: 5))
        #expect(shrunk.rect == CGRect(x: 0, y: 0, width: 20, height: 20))
    }

    @Test("Resizing a segment moves one end and refreshes its rect")
    func resizingSegment() {
        let arrow = ScreenshotAnnotation.arrow(start: .zero, end: CGPoint(x: 50, y: 50), style: style)
        let resized = arrow.resized(handle: .arrowEnd, to: CGPoint(x: 10, y: 10))
        #expect(resized.startPoint == .zero)
        #expect(resized.endPoint == CGPoint(x: 10, y: 10))
        #expect(resized.rect == CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    // MARK: Constraints

    @Test("Shift snaps a segment to the nearest 45 degrees and keeps its length")
    func snapping() {
        let flat = AnnotationConstraint.snappedSegmentEnd(start: .zero, end: CGPoint(x: 100, y: 10))
        #expect(abs(flat.y) < 0.001)
        #expect(abs(flat.x - hypot(100, 10)) < 0.001)

        let diagonal = AnnotationConstraint.snappedSegmentEnd(start: .zero, end: CGPoint(x: 10, y: 9))
        #expect(abs(diagonal.x - diagonal.y) < 0.001)
        #expect(abs(hypot(diagonal.x, diagonal.y) - hypot(10, 9)) < 0.001)

        #expect(AnnotationConstraint.snappedSegmentEnd(start: .zero, end: .zero) == .zero)
    }

    @Test("Shift makes a drag square, anchored at the start in any direction")
    func squares() {
        #expect(AnnotationConstraint.squareRect(start: CGPoint(x: 10, y: 10), end: CGPoint(x: 60, y: 30))
                == CGRect(x: 10, y: 10, width: 50, height: 50))
        #expect(AnnotationConstraint.squareRect(start: CGPoint(x: 10, y: 10), end: CGPoint(x: -40, y: 5))
                == CGRect(x: -40, y: -40, width: 50, height: 50))
    }

    // MARK: Session history

    @Test("A new session has nothing to undo and counts as unsaved until committed")
    func freshSession() {
        let session = session()
        #expect(!session.canUndo)
        #expect(!session.canRedo)
        #expect(session.currentSnapshot == .empty)
        #expect(session.hasUnsavedChanges)

        session.recordCommit(itemID: UUID())
        #expect(!session.hasUnsavedChanges)
        session.commit(snapshot: snapshot(box()))
        #expect(session.hasUnsavedChanges)
        session.undo()
        #expect(!session.hasUnsavedChanges)
    }

    @Test("Undo and redo walk the history; a new commit drops the redo branch")
    func undoRedo() {
        let session = session()
        session.commit(snapshot: snapshot(box(0)))
        session.commit(snapshot: snapshot(box(0), box(200)))
        #expect(session.currentSnapshot.annotations.count == 2)

        session.undo()
        #expect(session.currentSnapshot.annotations.count == 1)
        #expect(session.canRedo)
        session.redo()
        #expect(session.currentSnapshot.annotations.count == 2)

        session.undo()
        session.commit(snapshot: snapshot(box(500)))
        #expect(!session.canRedo)
        #expect(session.history.count == 3)
    }

    @Test("History is capped at 100 snapshots, keeping the newest")
    func historyCap() {
        let session = session()
        for index in 0..<105 {
            session.commit(snapshot: snapshot(box(Double(index))))
        }
        #expect(session.history.count == 100)
        #expect(session.historyIndex == 99)
        #expect(session.currentSnapshot.annotations.first?.rect.minX == 104)
    }

    @Test("Undo clears a selection that no longer exists")
    func selectionClearedByUndo() {
        let session = session()
        let mark = box()
        session.commit(snapshot: snapshot(mark))
        session.selectedAnnotationID = mark.id
        session.undo()
        #expect(session.selectedAnnotationID == nil)
    }

    @Test("Deleting the selection is one undoable step")
    func deleteSelection() {
        let session = session()
        let mark = box()
        session.commit(snapshot: snapshot(mark))
        session.selectedAnnotationID = mark.id
        session.deleteSelectedAnnotation()
        #expect(session.currentSnapshot.annotations.isEmpty)
        #expect(session.selectedAnnotationID == nil)
        session.undo()
        #expect(session.currentSnapshot.annotations.count == 1)

        let before = session.history.count
        session.deleteSelectedAnnotation()
        #expect(session.history.count == before)
    }

    @Test("The step counter continues after the highest number")
    func counterNumbering() {
        let session = session()
        #expect(session.nextCounterNumber == 1)
        session.commit(snapshot: snapshot(
            .counter(1, center: .zero, style: style),
            .counter(3, center: CGPoint(x: 50, y: 50), style: style),
            box()
        ))
        #expect(session.nextCounterNumber == 4)
    }

    @Test("Updating the selection commits an edit; with none selected it does nothing")
    func updateSelection() {
        let session = session()
        let mark = box()
        session.commit(snapshot: snapshot(mark))
        let before = session.history.count

        session.updateSelectedAnnotation { $0.lineWidth = 16 }
        #expect(session.history.count == before)

        session.selectedAnnotationID = mark.id
        session.updateSelectedAnnotation { $0.lineWidth = 16 }
        #expect(session.history.count == before + 1)
        #expect(session.currentSnapshot.annotations.first?.lineWidth == 16)
    }

    @Test("Repeated nudges of one mark are one undo step; any other edit starts a new one")
    func nudgeCoalescing() {
        let session = session()
        let mark = box()
        session.commit(snapshot: snapshot(mark))
        session.selectedAnnotationID = mark.id

        session.nudgeSelectedAnnotation(by: CGSize(width: 1, height: 0))
        session.nudgeSelectedAnnotation(by: CGSize(width: 1, height: 0))
        #expect(session.history.count == 3)
        #expect(session.currentSnapshot.annotations.first?.rect.minX == 2)
        session.undo()
        #expect(session.currentSnapshot.annotations.first?.rect.minX == 0)
        session.redo()

        session.updateSelectedAnnotation { $0.lineWidth = 10 }
        session.nudgeSelectedAnnotation(by: CGSize(width: 1, height: 0))
        #expect(session.history.count == 5)
    }

    @Test("Duplicating for editing copies the current state with a fresh history")
    func duplicate() {
        let session = session()
        session.commit(snapshot: snapshot(box()))
        session.recordCommit(itemID: UUID())

        let copy = session.duplicateForEditing()
        #expect(copy.currentSnapshot == session.currentSnapshot)
        #expect(copy.history.count == 1)
        #expect(!copy.canUndo)
        #expect(copy.committedItemID == session.committedItemID)
        #expect(!copy.hasUnsavedChanges)
    }

    @Test("The visible rect is the whole canvas until a crop is committed")
    func visibleRect() {
        let session = session()
        let crop = CGRect(x: 10, y: 10, width: 50, height: 50)
        session.commit(snapshot: ScreenshotDocumentSnapshot(cropRect: crop, annotations: []))
        #expect(session.visibleImageRect == crop)
        session.undo()
        #expect(session.visibleImageRect == .zero)
    }
}
#endif
