import AppKit
import SwiftUI

struct CodableColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.deviceRGB) ?? .systemRed
        self.red = converted.redComponent.doubleValue
        self.green = converted.greenComponent.doubleValue
        self.blue = converted.blueComponent.doubleValue
        self.alpha = converted.alphaComponent.doubleValue
    }

    var nsColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    static let systemRed = CodableColor(nsColor: .systemRed)
    static let systemOrange = CodableColor(nsColor: .systemOrange)
}

private extension CGFloat {
    var doubleValue: Double { Double(self) }
}
