import AppKit
import Foundation

final class CaptureEngine {
    static let imageDataUserInfoKey = "imageData"

    func captureArea() {
        runScreencaptureFallback(arguments: ["-i", "-c"])
    }

    func captureWindow() {
        runScreencaptureFallback(arguments: ["-i", "-w", "-c"])
    }

    func captureFullScreen() {
        runScreencaptureFallback(arguments: ["-c"])
    }

    private func runScreencaptureFallback(arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                let imageData = NSPasteboard.general.data(forType: .tiff)
                NotificationCenter.default.post(
                    name: .edisonScreenshotCaptured,
                    object: nil,
                    userInfo: [Self.imageDataUserInfoKey: imageData as Any]
                )
            }
        }
        try? process.run()
    }
}
