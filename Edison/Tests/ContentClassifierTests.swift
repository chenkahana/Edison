import Foundation

#if canImport(Testing)
import Testing
@testable import Edison

/// The classifier decides which badge, preview and filter an item gets, so a wrong call is a visible mistake.
/// These pin the unambiguous cases; the heuristics' grey zone is deliberately not asserted.
struct ContentClassifierTests {
    private let swiftSnippet = "func add(a: Int, b: Int) -> Int {\n    return a + b\n}"

    // MARK: Links

    @Test("A bare web, mail or ftp address is a link", arguments: [
        "https://example.com/path?q=1",
        "http://example.com",
        "mailto:hi@example.com",
        "ftp://files.example.com"
    ])
    func recognisesLinks(text: String) {
        #expect(ClipboardContentClassifier.kind(forText: text) == .link)
    }

    @Test("Things that only resemble links stay text", arguments: [
        "example.com",
        "https://localhost",
        "see https://example.com",
        "javascript:alert(1)"
    ])
    func rejectsNonLinks(text: String) {
        #expect(ClipboardContentClassifier.kind(forText: text) != .link)
    }

    @Test("A link is a link even from a terminal app")
    func linkBeatsTerminalSource() {
        let kind = ClipboardContentClassifier.kind(forText: "https://example.com", sourceBundleIdentifier: "com.apple.Terminal")
        #expect(kind == .link)
    }

    // MARK: Colours

    @Test("Hex colours parse in every length")
    func parsesHex() throws {
        let long = try #require(ClipboardContentClassifier.color(in: "#FF9400"))
        #expect(long.hexString == "#FF9400")
        #expect(long.alpha == 1)

        let short = try #require(ClipboardContentClassifier.color(in: "#f90"))
        #expect(short.hexString == "#FF9900")

        let prefixed = try #require(ClipboardContentClassifier.color(in: "0xFF9400"))
        #expect(prefixed.hexString == "#FF9400")

        let withAlpha = try #require(ClipboardContentClassifier.color(in: "#ffffff80"))
        #expect(withAlpha.hexString == "#FFFFFF")
        #expect(abs(withAlpha.alpha - 128.0 / 255.0) < 0.001)
    }

    @Test("rgb and hsl colours parse")
    func parsesFunctional() throws {
        let rgb = try #require(ClipboardContentClassifier.color(in: "rgb(255 148 0)"))
        #expect(rgb.hexString == "#FF9400")

        let percent = try #require(ClipboardContentClassifier.color(in: "rgb(100%, 0%, 0%)"))
        #expect(percent.hexString == "#FF0000")

        let translucent = try #require(ClipboardContentClassifier.color(in: "rgba(0, 0, 0, 0.5)"))
        #expect(translucent.hexString == "#000000")
        #expect(abs(translucent.alpha - 0.5) < 0.001)

        let red = try #require(ClipboardContentClassifier.color(in: "hsl(0, 100%, 50%)"))
        #expect(red.hexString == "#FF0000")

        let green = try #require(ClipboardContentClassifier.color(in: "hsl(120, 100%, 50%)"))
        #expect(green.hexString == "#00FF00")
    }

    @Test("Malformed colours are not colours", arguments: [
        "#12345", "#GGG", "rgb(255, 0)", "red", "ff9400", "hsl(0, 100%)"
    ])
    func rejectsMalformedColours(text: String) {
        #expect(ClipboardContentClassifier.color(in: text) == nil)
    }

    @Test("Swatch label colour follows luminance")
    func lightness() throws {
        #expect(try #require(ClipboardContentClassifier.color(in: "#FFFFFF")).isLight)
        #expect(try !#require(ClipboardContentClassifier.color(in: "#000000")).isLight)
    }

    @Test("A colour is classified as a colour")
    func colourKind() {
        #expect(ClipboardContentClassifier.kind(forText: "  #FF9400\n") == .color)
    }

    // MARK: Text, code and terminal

    @Test("Empty, plain and oversized text is confidently text")
    func plainText() {
        for text in ["", "   \n", "hello world", String(repeating: "a", count: 20_001)] {
            let result = ClipboardContentClassifier.classify(text: text)
            #expect(result.kind == .text)
            #expect(result.isConfident)
        }
    }

    @Test("A sentence that happens to contain an arrow is text")
    func sentenceWithArrow() {
        let result = ClipboardContentClassifier.classify(text: "Works for me -> merging now.")
        #expect(result.kind == .text)
        #expect(result.isConfident)
    }

    @Test("Multi-line source is confidently code")
    func sourceCode() {
        let result = ClipboardContentClassifier.classify(text: swiftSnippet)
        #expect(result.kind == .code)
        #expect(result.isConfident)
        #expect(ClipboardContentClassifier.kind(forText: "#!/bin/bash\necho hi") == .code)
    }

    @Test("Prompts and tracebacks are confidently terminal output")
    func terminalOutput() {
        let prompt = ClipboardContentClassifier.classify(text: "$ git status\nOn branch main")
        #expect(prompt.kind == .terminal)
        #expect(prompt.isConfident)

        let trace = "Traceback (most recent call last):\n  File \"a.py\", line 1, in <module>"
        #expect(ClipboardContentClassifier.kind(forText: trace) == .terminal)
    }

    @Test("Text from a terminal app is terminal output, unless it reads as source code")
    func terminalSource() {
        let terminal = "com.apple.Terminal"
        #expect(ClipboardContentClassifier.kind(forText: "hello", sourceBundleIdentifier: terminal) == .terminal)
        #expect(ClipboardContentClassifier.kind(forText: swiftSnippet, sourceBundleIdentifier: terminal) == .code)
        #expect(ClipboardContentClassifier.kind(forText: "hello", sourceBundleIdentifier: "com.apple.TextEdit") == .text)
    }

    @Test("Only known terminal emulators count as terminal apps")
    func terminalApplications() {
        #expect(TerminalOutputHeuristic.isTerminalApplication("com.googlecode.iterm2"))
        #expect(!TerminalOutputHeuristic.isTerminalApplication("com.microsoft.VSCode"))
        #expect(!TerminalOutputHeuristic.isTerminalApplication(nil))
    }

    // MARK: Payloads

    @Test("Files and images are classified by payload, not by name")
    func payloadKinds() {
        #expect(ClipboardContentClassifier.kind(for: .fileURL(URL(fileURLWithPath: "/tmp/#FF9400.txt"))) == .file)
        let image = ClipboardImageData(imagePath: "stub.png", thumbnailPath: "stub-thumb.png")
        #expect(ClipboardContentClassifier.kind(for: .image(image)) == .image)
        #expect(ClipboardContentClassifier.kind(for: .text("https://example.com")) == .link)
    }
}
#endif
