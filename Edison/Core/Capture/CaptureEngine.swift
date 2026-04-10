import AppKit
import Foundation

final class CaptureEngine {
    static let imageDataUserInfoKey = "imageData"

    func captureArea() {
        runScreencapture(mode: .area)
    }

    func captureWindow() {
        runScreencapture(mode: .window)
    }

    func captureFullScreen() {
        runScreencapture(mode: .fullScreen)
    }

    private enum CaptureMode {
        case area
        case window
        case fullScreen

        var arguments: [String] {
            switch self {
            case .area:
                return ["-i", "-x"]
            case .window:
                return ["-i", "-w", "-x"]
            case .fullScreen:
                return ["-x"]
            }
        }
    }

    private func runScreencapture(mode: CaptureMode) {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("edison-screenshot-\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = mode.arguments + [outputURL.path]

        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                defer {
                    try? FileManager.default.removeItem(at: outputURL)
                }

                guard
                    process.terminationStatus == 0,
                    let imageData = try? Data(contentsOf: outputURL)
                else {
                    return
                }

                NotificationCenter.default.post(
                    name: .edisonScreenshotCaptured,
                    object: nil,
                    userInfo: [Self.imageDataUserInfoKey: imageData]
                )
            }
        }

        do {
            try process.run()
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
        }
    }
}
