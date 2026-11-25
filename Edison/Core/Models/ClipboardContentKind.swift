import Foundation

/// What a clipboard item *looks like* to a person, derived from its payload without changing it.
enum ClipboardContentKind: String, CaseIterable, Hashable, Codable {
    case text
    case link
    case color
    case code
    case terminal
    case image
    case file

    var title: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .color: return "Colour"
        case .code: return "Code"
        case .terminal: return "Terminal"
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
        case .terminal: return "terminal"
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
    static func kind(for payload: ClipboardPayload, sourceBundleIdentifier: String? = nil) -> ClipboardContentKind {
        switch payload {
        case .image: return .image
        case .fileURL: return .file
        case let .text(text): return kind(forText: text, sourceBundleIdentifier: sourceBundleIdentifier)
        }
    }

    static func kind(forText text: String, sourceBundleIdentifier: String? = nil) -> ClipboardContentKind {
        classify(text: text, sourceBundleIdentifier: sourceBundleIdentifier).kind
    }

    /// Links and colours are recognised first, whatever the source. Text copied from a terminal
    /// app is terminal output unless it reads as source code with no shell output in it (`cat`
    /// of a file); elsewhere, prompts, logs, stack traces and command output make it terminal.
    ///
    /// `isConfident` is false where the text has some code or terminal features but not enough to
    /// be sure; only there may the on-device model's label replace this one.
    static func classify(
        text: String,
        sourceBundleIdentifier: String? = nil
    ) -> (kind: ClipboardContentKind, isConfident: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 20_000 else { return (.text, true) }
        if link(in: trimmed) != nil { return (.link, true) }
        if color(in: trimmed) != nil { return (.color, true) }
        // The heuristics only need the start of the text; this bounds their cost on long items.
        let sample = String(trimmed.prefix(4_000))
        let terminal = TerminalOutputHeuristic.signal(in: sample)
        let code = codeEvidence(sample)
        if TerminalOutputHeuristic.isTerminalApplication(sourceBundleIdentifier) {
            return (terminal == .none && code >= .likely ? .code : .terminal, true)
        }
        if terminal == .strong || terminal == .likely { return (.terminal, true) }
        switch code {
        case .strong: return (.code, true)
        case .likely: return (.code, false)
        case .hint: return (.text, looksLikeSentence(trimmed))
        case .none: return (.text, terminal == .none)
        }
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

    /// Keywords that start a line of code (after its indentation). Prose rarely starts a line
    /// with these, unlike "return" or "->" anywhere in a sentence.
    private static let lineLeadingKeywords = [
        "func ", "def ", "class ", "import ", "from ", "#include", "#import", "const ", "let ", "var ",
        "return ", "public ", "private ", "internal ", "static ", "fn ", "package ", "struct ", "enum ",
        "guard ", "if (", "if let ", "for (", "while (", "switch ", "export ", "async ", "@", "#!/",
        "SELECT ", "FROM ", "WHERE ", "INSERT ", "UPDATE ", "DELETE ", "CREATE ", "JOIN ", "LEFT JOIN ",
        "GROUP BY ", "ORDER BY ", "<div", "<span", "<html", "<?xml", "// ", "/*"
    ]
    private static let codeOperators = ["->", "=>", "==", "!=", "&&", "||", "+=", "</", "/>", "::", "${", ":="]

    /// "Works for me -> merging now." is a sentence that happens to contain an arrow, not code.
    private static func looksLikeSentence(_ trimmed: String) -> Bool {
        guard let first = trimmed.first, let last = trimmed.last else { return false }
        return first.isUppercase && ".!?".contains(last) && trimmed.filter { $0 == " " }.count >= 3
    }

    enum CodeEvidence: Int, Comparable {
        case none, hint, likely, strong

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static func looksLikeCode(_ trimmed: String) -> Bool {
        codeEvidence(trimmed) >= .likely
    }

    static func codeEvidence(_ trimmed: String) -> CodeEvidence {
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: true)
        let symbolCount = trimmed.reduce(into: 0) { count, character in
            if "{};=<>[]".contains(character) { count += 1 }
        }
        let density = Double(symbolCount) / Double(max(trimmed.count, 1))
        let keywordLines = lines.filter { line in
            let start = line.drop(while: { $0 == " " || $0 == "\t" })
            return lineLeadingKeywords.contains { start.hasPrefix($0) }
        }.count
        let operatorCount = codeOperators.reduce(0) { $0 + (trimmed.contains($1) ? 1 : 0) }
        // Indented list items ("    - milk") are outlines, not code.
        let indentedLines = lines.filter { line in
            guard line.hasPrefix("  ") || line.hasPrefix("\t") else { return false }
            let start = line.drop(while: { $0 == " " || $0 == "\t" })
            return !(start.hasPrefix("- ") || start.hasPrefix("* ") || start.hasPrefix("• "))
        }.count
        let endsWithCodePunctuation = lines.filter { line in
            guard let last = line.last else { return false }
            return ";{}".contains(last)
        }.count

        if trimmed.hasPrefix("#!/") { return .strong }
        if lines.count >= 2 {
            let structural = endsWithCodePunctuation + indentedLines
            if keywordLines > 0 && (structural > 0 || density > 0.04) { return .strong }
            if Double(keywordLines + endsWithCodePunctuation) / Double(lines.count) >= 0.3 { return .strong }
            if Double(structural) / Double(lines.count) >= 0.4 { return .strong }
        } else {
            let endsLikeCode = endsWithCodePunctuation > 0 && density > 0.04
            if (keywordLines > 0 && (operatorCount > 0 || density > 0.04)) || endsLikeCode
                || (operatorCount >= 2 && density > 0.06) {
                return .likely
            }
        }
        let hasCodeFeatures = keywordLines > 0 || operatorCount > 0 || endsWithCodePunctuation > 0 || density > 0.04
        return hasCodeFeatures ? .hint : .none
    }
}

/// Recognises what a terminal prints: shell prompts, `ls -l` listings, timestamped log lines,
/// stack traces, compiler diagnostics and the output of common commands.
enum TerminalOutputHeuristic {
    enum Signal {
        case none
        /// Some lines look like output, but not enough to call the whole item terminal output.
        case weak
        /// Enough output-looking lines that the item is terminal output.
        case likely
        /// A line that only a terminal prints, such as a prompt or a traceback header.
        case strong
    }

    /// Terminal emulators by bundle identifier. VS Code's integrated terminal copies text with no
    /// marker that tells it apart from the editor, so VS Code relies on the text heuristic.
    static let terminalBundleIdentifiers: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "dev.warp.Warp",
        "dev.warp.Warp-Preview",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "io.alacritty",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
        "org.tabby",
        "com.raphaelamorim.rio"
    ]

    static func isTerminalApplication(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return terminalBundleIdentifiers.contains(bundleIdentifier)
    }

    // Each alternative is anchored to a line start, so one match is one line.
    private static let strongPattern = try! NSRegularExpression(
        pattern: [
            #"^\$ [a-z./~_]"#,                                     // $ command
            #"^% [a-z./~_]"#,                                       // % command (zsh)
            #"^[❯➜λ»] +\S"#,                                        // starship, oh-my-zsh, …
            #"^(\(\S+\) )?[\w.-]+@[\w.-]+[^\n]{0,80}?[$#%] \S"#,   // user@host:~$ cmd, (venv) user@host dir % cmd
            #"^PS [A-Z]:\\[^\n>]*> "#,                              // PowerShell
            #"^Traceback \(most recent call last\):"#,
            #"^Exception in thread "#,
            #"^Thread \d+( Crashed)?:"#,
            #"^commit [0-9a-f]{7,40}\b"#,
            #"^On branch \S+"#,
            #"^Changes (not staged|to be committed)"#,
            #"^(fatal error|error|fatal|panic): "#,                  // swiftc, git, Go
            #"^goroutine \d+ \["#,
            #"^ \d+ files? changed"#,                               // git diff --stat
            #"^[^\s:]+:\d+:\d+: (error|warning|note): "#,          // clang/swiftc diagnostics
            #"^\S+\(\d+,\d+\): error TS\d+"#,                     // tsc diagnostics
            #": command not found"#,
            #"^\S+: \S[^\n]*: No such file or directory$"#,
            #"^npm (ERR!|WARN|error|warn) "#,
            #"^==> \S"#                                             // Homebrew
        ].joined(separator: "|"),
        options: [.anchorsMatchLines]
    )

    private static let weakLinePattern = try! NSRegularExpression(
        pattern: "^(?:" + [
            #"total \d+$"#,                                         // ls -l header
            #"[-dlcbps][rwxsStT-]{9}[@+.]?\s+\d+\s"#,                 // ls -l entry
            #"\[?\d{4}[-/]\d{2}[-/]\d{2}[T ]\d{2}:\d{2}"#,           // 2026-11-25 10:14 / [2026-11-25T08:12
            #"\[?\d{2}:\d{2}:\d{2}[.,\]\s]"#,                       // 10:14:03.123
            #"[A-Z][a-z]{2} [ \d]\d \d{2}:\d{2}:\d{2} "#,             // syslog: Nov 25 09:41:12
            #"(?=[0-9a-f]*\d)[0-9a-f]{7,12} \S"#,                    // git log --oneline
            #" \S+\s+\|\s+\d+ [+-]*$"#,                              // git diff --stat entry
            #"(added|removed|changed|audited) \d+ packages?"#,       // npm/yarn summaries
            #"found \d+ vulnerabilit"#,
            #"\s+at \S[^\n]*[(\s]\S*:\d+(:\d+)?\)?$"#,             // JS/Java stack frame
            #"\s+File "[^"]+", line \d+"#,                          // Python frame
            #"\d+\s+\S+\s+0x[0-9a-fA-F]+ "#,                        // crash report frame
            #"Author: [^\n]+<[^\n]+>"#,
            #"Date: {3}"#,
            #"\s*(PID|USER|Filesystem|NAME|CONTAINER ID|REPOSITORY|COMMAND)\s{2,}"#, // CLI table headers
            #"\d+ bytes from "#,
            #"PING "#,
            #"\[\d+/\d+\] "#,                                      // build progress
            #"#{10,}"#,                                             // progress bars
            #"\s+(modified|new file|deleted|renamed):\s+\S"#          // git status entries
        ].joined(separator: "|") + ")",
        options: [.anchorsMatchLines]
    )

    static func signal(in sample: String) -> Signal {
        let range = NSRange(sample.startIndex..., in: sample)
        if strongPattern.firstMatch(in: sample, range: range) != nil { return .strong }
        let matchingLines = weakLinePattern.numberOfMatches(in: sample, range: range)
        guard matchingLines > 0 else { return .none }
        let lineCount = sample.split(separator: "\n", omittingEmptySubsequences: true).count
        return Double(matchingLines) / Double(max(lineCount, 1)) >= 0.4 ? .likely : .weak
    }
}

extension ClipboardItem {
    var contentKind: ClipboardContentKind {
        guard case let .text(text) = payload else {
            return ClipboardContentClassifier.kind(for: payload)
        }
        // Cards ask for their kind on every render; an item's payload and source never change.
        let key = id as NSUUID
        let classified: ClipboardContentKindCache.Entry
        if let cached = ClipboardContentKindCache.shared.object(forKey: key) {
            classified = cached
        } else {
            let result = ClipboardContentClassifier.classify(
                text: text,
                sourceBundleIdentifier: sourceApplication?.bundleIdentifier
            )
            classified = ClipboardContentKindCache.Entry(kind: result.kind, isConfident: result.isConfident)
            ClipboardContentKindCache.shared.setObject(classified, forKey: key)
        }
        return ClipboardIntelligence.resolvedKind(
            classified: classified.kind,
            isConfident: classified.isConfident,
            modelKind: intelligence?.modelKind
        )
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

private enum ClipboardContentKindCache {
    final class Entry {
        let kind: ClipboardContentKind
        let isConfident: Bool

        init(kind: ClipboardContentKind, isConfident: Bool) {
            self.kind = kind
            self.isConfident = isConfident
        }
    }

    static let shared: NSCache<NSUUID, Entry> = {
        let cache = NSCache<NSUUID, Entry>()
        cache.countLimit = 2_000
        return cache
    }()
}
