import AppKit

/// Draws annotations into a Core Graphics context in image coordinates (points, bottom-left origin).
///
/// The editor canvas and the exported PNG both use this renderer, so the preview is exactly what
/// gets copied, saved, or dragged out.
enum ScreenshotAnnotationRenderer {
    static func strokeWidth(for annotation: ScreenshotAnnotation) -> CGFloat {
        annotation.kind == .highlighter
            ? CGFloat(max(14, annotation.lineWidth * 3))
            : CGFloat(annotation.lineWidth)
    }

    static func textFont(size: Double) -> NSFont {
        NSFont.systemFont(ofSize: CGFloat(size), weight: .bold)
    }

    static func textSize(_ text: String, fontSize: Double) -> CGSize {
        let measured = NSAttributedString(
            string: text.isEmpty ? " " : text,
            attributes: [.font: textFont(size: fontSize)]
        ).size()
        return CGSize(width: ceil(max(measured.width, 12)), height: ceil(measured.height))
    }

    static func fontSize(fittingHeight height: CGFloat) -> Double {
        Double(height / 1.2)
    }

    /// - Parameters:
    ///   - displayScale: device units per image point, used to keep shadows visually constant.
    ///   - canvasSize: full base image size in points (pixelated sources cover this rect).
    ///   - pixelatedSource: returns the base image pixelated with the given block size.
    static func draw(
        _ annotations: [ScreenshotAnnotation],
        in context: CGContext,
        displayScale: CGFloat,
        canvasSize: CGSize,
        pixelatedSource: (Double) -> CGImage?
    ) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }

        for annotation in annotations {
            context.saveGState()
            draw(
                annotation,
                in: context,
                displayScale: displayScale,
                canvasSize: canvasSize,
                pixelatedSource: pixelatedSource
            )
            context.restoreGState()
        }
    }

    private static func draw(
        _ annotation: ScreenshotAnnotation,
        in context: CGContext,
        displayScale: CGFloat,
        canvasSize: CGSize,
        pixelatedSource: (Double) -> CGImage?
    ) {
        if annotation.kind == .redact {
            guard let pixelated = pixelatedSource(annotation.blurRadius) else { return }
            context.clip(to: annotation.rect.standardized)
            context.interpolationQuality = .none
            context.draw(pixelated, in: CGRect(origin: .zero, size: canvasSize))
            return
        }

        let color = annotation.color.nsColor
        if annotation.kind == .highlighter {
            context.setAlpha(0.42)
        } else {
            // A soft dark halo keeps marks legible on both light and dark screenshots.
            context.setShadow(
                offset: .zero,
                blur: 3.5 * displayScale,
                color: NSColor.black.withAlphaComponent(0.42).cgColor
            )
        }

        context.beginTransparencyLayer(auxiliaryInfo: nil)
        defer { context.endTransparencyLayer() }

        let width = strokeWidth(for: annotation)
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.kind {
        case .rectangle:
            let rect = annotation.rect.standardized
            let radius = min(width, rect.width / 2, rect.height / 2)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.strokePath()

        case .ellipse:
            context.strokeEllipse(in: annotation.rect.standardized)

        case .line:
            guard let start = annotation.startPoint, let end = annotation.endPoint else { return }
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()

        case .arrow:
            guard let start = annotation.startPoint, let end = annotation.endPoint else { return }
            drawArrow(from: start, to: end, width: width, in: context)

        case .pen, .highlighter:
            context.addPath(smoothPath(through: annotation.points))
            context.strokePath()

        case .text:
            let attributes: [NSAttributedString.Key: Any] = [
                .font: textFont(size: annotation.fontSize),
                .foregroundColor: color
            ]
            NSAttributedString(string: annotation.text, attributes: attributes).draw(at: annotation.rect.origin)

        case .counter:
            drawCounter(annotation, color: color, in: context)

        case .redact:
            break
        }
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, width: CGFloat, in context: CGContext) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 2 else { return }

        let ux = dx / length
        let uy = dy / length
        let headLength = min(max(width * 3.4, 16), length * 0.85)
        let headHalfWidth = headLength * 0.48
        let base = CGPoint(x: end.x - ux * headLength, y: end.y - uy * headLength)
        // Stop the shaft inside the head so the round cap never pokes through the tip.
        let shaftEnd = CGPoint(x: base.x + ux * headLength * 0.35, y: base.y + uy * headLength * 0.35)

        context.move(to: start)
        context.addLine(to: shaftEnd)
        context.strokePath()

        let left = CGPoint(x: base.x - uy * headHalfWidth, y: base.y + ux * headHalfWidth)
        let right = CGPoint(x: base.x + uy * headHalfWidth, y: base.y - ux * headHalfWidth)
        context.move(to: end)
        context.addLine(to: left)
        context.addLine(to: right)
        context.closePath()
        context.setLineWidth(max(1, width * 0.35))
        context.drawPath(using: .fillStroke)
    }

    private static func drawCounter(_ annotation: ScreenshotAnnotation, color: NSColor, in context: CGContext) {
        let rect = annotation.rect.standardized
        context.fillEllipse(in: rect)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(max(1.5, rect.width * 0.06))
        context.strokeEllipse(in: rect.insetBy(dx: rect.width * 0.03, dy: rect.height * 0.03))

        let font = NSFont.systemFont(ofSize: rect.height * 0.52, weight: .heavy)
        let label = NSAttributedString(
            string: "\(annotation.number)",
            attributes: [.font: font, .foregroundColor: NSColor.white]
        )
        let size = label.size()
        label.draw(at: CGPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2 + font.descender * 0.5
        ))
    }

    static func smoothPath(through points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else {
            path.addLine(to: first)
            return path
        }
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: mid, control: previous)
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}
