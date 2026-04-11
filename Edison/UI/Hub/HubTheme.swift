import AppKit
import SwiftUI

enum HubTheme {
    enum Radius {
        static let window: CGFloat = 28
        static let card: CGFloat = 18
        static let menu: CGFloat = 12
        static let pill: CGFloat = 999
    }

    enum Space {
        static let x1: CGFloat = 4
        static let x2: CGFloat = 8
        static let x3: CGFloat = 12
        static let x4: CGFloat = 16
        static let x5: CGFloat = 20
        static let x6: CGFloat = 24
    }

    static let shelfWindowSize = CGSize(width: 1440, height: 278)
    static let searchPillHeight: CGFloat = 36
    static let minimumCardSide: CGFloat = 148
    static let maximumCardSide: CGFloat = 220

    enum Anim {
        static let fast: Double = 0.12
        static let standard: Double = 0.20
        static let emphasis: Double = 0.28
        static let spring = Animation.spring(response: 0.32, dampingFraction: 0.82, blendDuration: 0)
        static let fastSpring = Animation.spring(response: 0.22, dampingFraction: 0.80, blendDuration: 0)
    }

    static func cardSide(for availableHeight: CGFloat) -> CGFloat {
        let target = floor(availableHeight - (Space.x2 + Space.x1))
        return min(maximumCardSide, max(minimumCardSide, target))
    }

    static func accentColor(for item: ClipboardItem) -> Color {
        switch item.payload {
        case let .text(text):
            if text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("http") {
                return Color(hex: 0x0A84FF)
            }
            return Color(hex: 0x34C759)
        case .image:
            return Color(hex: 0xFF3B30)
        case .fileURL:
            return Color(hex: 0x8E8E93)
        }
    }

    static let accentBrand = Color(hex: 0xFF9400)
    static let accentBrandAlt = Color(hex: 0xFFB250)

    static let textPrimary = Color(nsColor: dynamicColor(
        light: NSColor(white: 0, alpha: 0.90),
        dark: NSColor(white: 1, alpha: 0.92)
    ))
    static let textSecondary = Color(nsColor: dynamicColor(
        light: NSColor(white: 0, alpha: 0.60),
        dark: NSColor(white: 1, alpha: 0.70)
    ))
    static let textTertiary = Color(nsColor: dynamicColor(
        light: NSColor(white: 0, alpha: 0.38),
        dark: NSColor(white: 1, alpha: 0.45)
    ))
    static let glassBase = Color(nsColor: dynamicColor(
        light: NSColor(calibratedWhite: 1, alpha: 0.52),
        dark: NSColor(calibratedWhite: 0.13, alpha: 0.58)
    ))
    static let glassTintWarm = Color(nsColor: dynamicColor(
        light: NSColor(calibratedRed: 1, green: 180 / 255, blue: 90 / 255, alpha: 0.10),
        dark: NSColor(calibratedRed: 1, green: 148 / 255, blue: 0, alpha: 0.10)
    ))
    static let glassStroke = Color(nsColor: dynamicColor(
        light: NSColor(calibratedWhite: 1, alpha: 0.26),
        dark: NSColor(calibratedWhite: 1, alpha: 0.08)
    ))
    static let dividerOnGlass = Color(nsColor: dynamicColor(
        light: NSColor(calibratedWhite: 0, alpha: 0.10),
        dark: NSColor(calibratedWhite: 1, alpha: 0.10)
    ))
    static let selectionFill = Color(nsColor: dynamicColor(
        light: NSColor(calibratedRed: 0, green: 122 / 255, blue: 1, alpha: 0.18),
        dark: NSColor(calibratedRed: 10 / 255, green: 132 / 255, blue: 1, alpha: 0.28)
    ))
    static let cardFill = Color(nsColor: dynamicColor(
        light: NSColor(calibratedWhite: 1, alpha: 0.18),
        dark: NSColor(calibratedWhite: 0.16, alpha: 0.22)
    ))
    static let cardFillMuted = Color(nsColor: dynamicColor(
        light: NSColor(calibratedWhite: 1, alpha: 0.10),
        dark: NSColor(calibratedWhite: 0.14, alpha: 0.14)
    ))
    static let opaqueFallback = Color(nsColor: dynamicColor(
        light: NSColor(calibratedWhite: 0.95, alpha: 1),
        dark: NSColor(calibratedWhite: 0.11, alpha: 1)
    ))

    static func cardShadowKey(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.55)
            : Color.black.opacity(0.18)
    }

    static func cardShadowAmbient(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.30)
            : Color.black.opacity(0.08)
    }

    private static func dynamicColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct HubGlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: HubTheme.Radius.window, style: .continuous)
                    .fill(HubTheme.opaqueFallback)
            } else {
                HubTheme.glassBase
                    .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.window, style: .continuous))

                VisualEffectView(
                    material: .hudWindow,
                    blendingMode: .behindWindow,
                    state: .active
                )
                .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.window, style: .continuous))

                RoundedRectangle(cornerRadius: HubTheme.Radius.window, style: .continuous)
                    .fill(HubTheme.glassTintWarm)

                RoundedRectangle(cornerRadius: HubTheme.Radius.window, style: .continuous)
                    .strokeBorder(HubTheme.glassStroke, lineWidth: 1)

                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.06 : 0.14),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: HubTheme.Radius.window, style: .continuous))
            }
        }
    }
}

enum HubShelfWindowStyle {
    static func apply(to window: NSWindow) {
        window.identifier = NSUserInterfaceItemIdentifier("hub-window")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient, .ignoresCycle]
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.remove(.resizable)
        window.toolbar = nil
        window.isExcludedFromWindowsMenu = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        guard let screen = window.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let width = visibleFrame.width
        let height = min(HubTheme.shelfWindowSize.height, visibleFrame.height)
        let frame = NSRect(
            x: visibleFrame.minX,
            y: visibleFrame.minY,
            width: width,
            height: height
        )

        if window.frame != frame {
            window.setFrame(frame, display: true, animate: false)
        }
    }
}

private extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
