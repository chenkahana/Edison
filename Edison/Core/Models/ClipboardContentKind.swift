import Foundation

/// What a clipboard item *looks like* to a person, derived from its payload without changing it.
enum ClipboardContentKind: String, CaseIterable, Hashable {
    case text
    case link
    case color
    case code
    case image
    case file

    var title: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .color: return "Colour"
        case .code: return "Code"
        case .image: return "Image"
        case .file: return "File"
        }
    }

    var symbolName: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .color: return "paintpalette"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}

/// An RGBA colour parsed from clipboard text such as `#FF9400`, `rgb(255 148 0)` or `hsl(35, 100%, 50%)`.
struct ClipboardColorValue: Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    var hexString: String {
        let r = Int((red * 255).rounded()), g = Int((green * 255).rounded()), b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Relative luminance, used to choose a legible label colour on top of the swatch.
    var isLight: Bool {
        0.2126 * red + 0.7152 * green + 0.0722 * blue > 0.6
    }
}

enum ClipboardContentClassifier {
    static func kind(for payload: ClipboardPayload) -> ClipboardContentKind {
        switch payload {
        case .image: return .image
        case .fileURL: return .file
        case let .text(text): return kind(forText: text)
        }
    }

    static func kind(forText text: String) -> ClipboardContentKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 20_000 else { return .text }
        if link(in: trimmed) != nil { return .link }
        if color(in: trimmed) != nil { return .color }
        if looksLikeCode(trimmed) { return .code }
        return .text
    }

    /// A single web or mail URL with nothing else around it.
    static func link(in trimmed: String) -> URL? {
        guard trimmed.count <= 2_048,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased() else { return nil }
        switch scheme {
        case "http", "https":
            return (url.host?.contains(".") ?? false) ? url : nil
        case "mailto", "ftp", "sftp":
            return url
        default:
            return nil
        }
    }

    static func color(in trimmed: String) -> ClipboardColorValue? {
        guard trimmed.count <= 64 else { return nil }
        let lower = trimmed.lowercased()
        if let hex = hexColor(lower) { return hex }
        if lower.hasPrefix("rgb") { return functionalColor(lower, isHSL: false) }
        if lower.hasPrefix("hsl") { return functionalColor(lower, isHSL: true) }
        return nil
    }

    private static func hexColor(_ text: String) -> ClipboardColorValue? {
        let body: Substring
        if text.hasPrefix("#") {
            body = text.dropFirst()
        } else if text.hasPrefix("0x") {
            body = text.dropFirst(2)
        } else {
            return nil
        }
        guard [3, 4, 6, 8].contains(body.count), body.allSatisfy(\.isHexDigit) else { return nil }
        let expanded = body.count <= 4 ? String(body.flatMap { [$0, $0] }) : String(body)
        guard let value = UInt64(expanded, radix: 16) else { return nil }
        let hasAlpha = expanded.count == 8
        let shift: UInt64 = hasAlpha ? 8 : 0
        return ClipboardColorValue(
            red: Double((value >> (16 + shift)) & 0xFF) / 255,
            green: Double((value >> (8 + shift)) & 0xFF) / 255,
            blue: Double((value >> shift) & 0xFF) / 255,
            alpha: hasAlpha ? Double(value & 0xFF) / 255 : 1
        )
    }

    private static func functionalColor(_ text: String, isHSL: Bool) -> ClipboardColorValue? {
        guard let open = text.firstIndex(of: "("), text.hasSuffix(")") else { return nil }
        let prefix = text[..<open]
        guard ["rgb", "rgba", "hsl", "hsla"].contains(prefix) else { return nil }
        let inner = text[text.index(after: open)..<text.index(before: text.endIndex)]
        let parts = inner
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count == 3 || parts.count == 4 else { return nil }

        func number(_ token: String, scale: Double) -> Double? {
            if token.hasSuffix("%") {
                return Double(token.dropLast()).map { $0 / 100 }
            }
            return Double(token.replacingOccurrences(of: "deg", with: "")).map { $0 / scale }
        }

        let alpha = parts.count == 4 ? (number(parts[3], scale: 1) ?? 1) : 1
        if isHSL {
            guard let hue = Double(parts[0].replacingOccurrences(of: "deg", with: "")),
                  let saturation = number(parts[1], scale: 100),
                  let lightness = number(parts[2], scale: 100) else { return nil }
            let (r, g, b) = hslToRGB(hue: hue, saturation: saturation, lightness: lightness)
            return ClipboardColorValue(red: r, green: g, blue: b, alpha: clamp(alpha))
        }
        guard let r = number(parts[0], scale: 255),
              let g = number(parts[1], scale: 255),
              let b = number(parts[2], scale: 255) else { return nil }
        return ClipboardColorValue(red: clamp(r), green: clamp(g), blue: clamp(b), alpha: clamp(alpha))
    }

    private static func hslToRGB(hue: Double, saturation: Double, lightness: Double) -> (Double, Double, Double) {
        let s = clamp(saturation), l = clamp(lightness)
        let h = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        guard s > 0 else { return (l, l, l) }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func channel(_ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }
        return (channel(h + 1 / 3), channel(h), channel(h - 1 / 3))
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    private static let codeKeywords = [
        "func ", "def ", "class ", "import ", "#include", "const ", "let ", "var ", "return ",
        "=> ", "->", "public ", "private ", "fn ", "SELECT ", "#!/", "</", "package ", "struct "
    ]

    static func looksLikeCode(_ trimmed: String) -> Bool {
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: true)
        let symbolCount = trimmed.reduce(into: 0) { count, character in
            if "{};()[]=<>".contains(character) { count += 1 }
        }
        let density = Double(symbolCount) / Double(max(trimmed.count, 1))
        let hasKeyword = codeKeywords.contains { trimmed.contains($0) }
        let indentedLines = lines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }.count
        let endsWithCodePunctuation = lines.filter { line in
            guard let last = line.last else { return false }
            return ";{}".contains(last)
        }.count

        if lines.count >= 2 {
            let structural = endsWithCodePunctuation + indentedLines
            return (hasKeyword && (density > 0.02 || structural > 0)) || Double(structural) / Double(lines.count) >= 0.4
        }
        return hasKeyword && density > 0.06
    }
}

extension ClipboardItem {
    var contentKind: ClipboardContentKind {
        ClipboardContentClassifier.kind(for: payload)
    }

    var linkURL: URL? {
        guard case let .text(text) = payload else { return nil }
        return ClipboardContentClassifier.link(in: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var colorValue: ClipboardColorValue? {
        guard case let .text(text) = payload else { return nil }
        return ClipboardContentClassifier.color(in: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
