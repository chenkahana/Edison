import CoreGraphics
import Foundation
import ImageIO
import OSLog
import Vision

/// Vision on the item's stored image (macOS 14+): text recognition, scene labels, barcodes and QR
/// codes, and a feature print for spotting near-duplicates. Synchronous; call it off the main thread.
enum OnDeviceImageAnalyzer {
    struct Result: Sendable {
        var recognizedText: String?
        var labels: [String]
        var barcodePayload: String?
        var featurePrint: Data?
    }

    /// Vision reads a copy no larger than this on its long side: enough for screenshot text at
    /// Retina sizes, and a bounded cost for huge images.
    static let maximumPixelSize = 2_048
    static let maximumRecognizedCharacters = 4_000
    /// Feature-print distance under which two images count as near-duplicates (calibrated on
    /// re-captures of the same window with small changes, against different windows).
    static let nearDuplicateDistance: Float = 0.35

    static func analyze(imageURL: URL) -> Result? {
        guard let image = downscaledImage(at: imageURL, maximumPixelSize: maximumPixelSize) else { return nil }

        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = true
        text.automaticallyDetectsLanguage = true
        let classify = VNClassifyImageRequest()
        let barcodes = VNDetectBarcodesRequest()
        let featurePrint = VNGenerateImageFeaturePrintRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([text, classify, barcodes, featurePrint])
        } catch {
            Log.intelligence.error("Vision failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let lines = (text.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let recognized = String(lines.joined(separator: "\n").prefix(maximumRecognizedCharacters))
        let labels = (classify.results ?? [])
            .filter { $0.confidence >= 0.3 }
            .prefix(3)
            .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
        let archived = featurePrint.results?.first.flatMap {
            try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
        }
        return Result(
            recognizedText: recognized.isEmpty ? nil : recognized,
            labels: Array(labels),
            barcodePayload: barcodes.results?.lazy.compactMap(\.payloadStringValue).first,
            featurePrint: archived
        )
    }

    static func distance(between first: Data, and second: Data) -> Float? {
        guard let a = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: first),
              let b = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: second) else {
            return nil
        }
        var distance: Float = 0
        do {
            try a.computeDistance(&distance, to: b)
        } catch {
            return nil
        }
        return distance
    }

    /// A decoded copy no larger than `maximumPixelSize` on its long side, without decoding the
    /// full-size image first.
    static func downscaledImage(at url: URL, maximumPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
