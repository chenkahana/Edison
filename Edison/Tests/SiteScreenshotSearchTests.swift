import Foundation
#if canImport(AppKit)
import AppKit
import SwiftUI
#endif

#if canImport(Testing)
import Testing
@testable import Edison

/// Seeds a real screenshot of the Edison site as a screenshot item, reads its text with the app's own Vision
/// analyzer, runs the app's real search for "meet Edison", and renders the real Hub at three beats (empty search,
/// query typed, matching result) to PNGs. Nothing here is a mockup: the pixels come from `HubView` itself.
///
/// PNGs go to `$EDISON_UI_ARTIFACTS`, or a temp folder when it is unset. The Search screenshots workflow uploads them.
@MainActor
struct SiteScreenshotSearchTests {
    private static let query = "meet Edison"

    private static var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Edison
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Fixtures/edison-site-screenshot.jpg")
    }

    private static var outputDirectory: URL {
        if let path = ProcessInfo.processInfo.environment["EDISON_UI_ARTIFACTS"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("edison-ui-artifacts", isDirectory: true)
    }

    private func pngData(from imageURL: URL, maxPixelSize: Int? = nil) throws -> Data {
        let image: CGImage
        if let maxPixelSize {
            image = try #require(OnDeviceImageAnalyzer.downscaledImage(at: imageURL, maximumPixelSize: maxPixelSize))
        } else {
            let source = try #require(CGImageSourceCreateWithURL(imageURL as CFURL, nil))
            image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        }
        return try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    }

    private func seededScreenshotItem() throws -> ClipboardItem {
        let id = UUID()
        let full = try pngData(from: Self.fixtureURL)
        let thumb = try pngData(from: Self.fixtureURL, maxPixelSize: 480)
        let item = ClipboardItem(
            id: id,
            createdAt: .now,
            payload: .image(ClipboardImageData(
                imagePath: try ImageStore.save(imageData: full, id: id),
                thumbnailPath: try ImageStore.saveThumbnail(data: thumb, id: id)
            ))
        )
        return item
    }

    private func render(_ appState: AppState, appearance: NSAppearance.Name, to url: URL) throws {
        let size = HubTheme.shelfWindowSize
        let host = NSHostingView(rootView: HubView().environmentObject(appState))
        host.frame = NSRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: appearance)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = host.appearance
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFrontRegardless()
        // Let SwiftUI lay out and the card thumbnails load before the snapshot.
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        host.layoutSubtreeIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let data = try #require(rep.representation(using: .png, properties: [:]))
        try data.write(to: url, options: .atomic)
        window.orderOut(nil)
    }

    @Test("Searching \"meet Edison\" finds the seeded site screenshot, and the real Hub renders each step")
    func searchFindsTheSeededScreenshot() throws {
        let item = try seededScreenshotItem()
        defer {
            if case let .image(data) = item.payload {
                for path in [data.imagePath, data.thumbnailPath] {
                    try? FileManager.default.removeItem(at: ImageStore.imagesDirectoryURL.appendingPathComponent(path))
                }
            }
        }

        // The app's own on-device pass reads the text in the image.
        let analysis = try #require(OnDeviceImageAnalyzer.analyze(
            imageURL: ImageStore.imagesDirectoryURL.appendingPathComponent({
                guard case let .image(data) = item.payload else { return "" }
                return data.imagePath
            }())
        ))
        let recognized = try #require(analysis.recognizedText)
        #expect(recognized.localizedCaseInsensitiveContains("meet edison"), "Vision read: \(recognized.prefix(300))")

        var seeded = item
        seeded.intelligence = ClipboardIntelligence(
            recognizedText: analysis.recognizedText,
            imageLabels: analysis.labels,
            barcodePayload: analysis.barcodePayload
        )
        let others = [
            makeTextItem("Ship Edison 2.1 on Friday: editor tools, typed cards, pause history."),
            makeTextItem("hello@example.com"),
            makeTextItem("func paste(_ item: ClipboardItem) { guard item.isReady else { return } }")
        ]
        let history = [seeded] + others

        // Real search engine, as the Hub uses it.
        let hits = HistorySearchEngine().filter(query: Self.query, in: history)
        #expect(hits.map(\.id) == [seeded.id])

        // Real app state and Hub UI, rendered at three beats in both appearances.
        let appState = AppState(enableRuntimeServices: false)
        appState.captureCoordinator.setHistoryItems(history)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        let directory = Self.outputDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", NSAppearance.Name.aqua)] {
            appState.activeQuery = ""
            try render(appState, appearance: appearance, to: directory.appendingPathComponent("01-empty-search-\(name).png"))
            appState.activeQuery = Self.query
            #expect(appState.filteredItems.first?.id == seeded.id)
            try render(appState, appearance: appearance, to: directory.appendingPathComponent("02-query-typed-\(name).png"))
            #expect(appState.filteredItems.first?.id == seeded.id)
            try render(appState, appearance: appearance, to: directory.appendingPathComponent("03-result-\(name).png"))
        }
    }
}
#endif
