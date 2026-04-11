import AppKit
import Foundation
import OSLog

enum ImageProcessing {
    nonisolated static func prepareImagePayload(from input: Data, id: UUID = UUID()) -> ClipboardImageData? {
        guard let image = NSImage(data: input) else { return nil }

        let optimized = image.resized(maxDimension: 2200)
        guard let optimizedData = optimized.pngData() else { return nil }

        let thumbnail = optimized.resized(maxDimension: 200)
        guard let thumbnailData = thumbnail.pngData() else { return nil }

        do {
            let imagePath = try ImageStore.save(imageData: optimizedData, id: id)
            let thumbnailPath = try ImageStore.saveThumbnail(data: thumbnailData, id: id)
            return ClipboardImageData(imagePath: imagePath, thumbnailPath: thumbnailPath)
        } catch {
            Log.store.error("ImageProcessing: failed to save image – \(error.localizedDescription)")
            return nil
        }
    }
}

private extension NSImage {
    nonisolated func resized(maxDimension: CGFloat) -> NSImage {
        let size = self.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }

        let ratio = maxDimension / longest
        let targetSize = NSSize(width: size.width * ratio, height: size.height * ratio)
        let output = NSImage(size: targetSize)

        output.lockFocus()
        draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1)
        output.unlockFocus()
        return output
    }

    nonisolated func pngData() -> Data? {
        guard
            let tiffData = tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}
