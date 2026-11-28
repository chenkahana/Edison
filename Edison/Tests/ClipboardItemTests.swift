import Foundation

#if canImport(Testing)
import Testing
@testable import Edison

/// Clipboard fidelity: two items are "the same" only when their bytes are, and counts are in Unicode scalars.
struct ClipboardItemTests {
    @Test("Text identity compares exact bytes, so visually equal text is not merged")
    func identityIsByteExact() {
        let composed = ClipboardItem(payload: .text("caf\u{00E9}"))
        let decomposed = ClipboardItem(payload: .text("cafe\u{0301}"))
        #expect(composed.hasSameClipboardIdentity(as: ClipboardItem(payload: .text("caf\u{00E9}"))))
        #expect(!composed.hasSameClipboardIdentity(as: decomposed))
        #expect(!ClipboardItem(payload: .text("a")).hasSameClipboardIdentity(as: ClipboardItem(payload: .text("a "))))
        #expect(!ClipboardItem(payload: .text("a\n")).hasSameClipboardIdentity(as: ClipboardItem(payload: .text("a"))))
    }

    @Test("Identity ignores id, date and favorite state")
    func identityIgnoresMetadata() {
        let a = ClipboardItem(createdAt: Date(timeIntervalSince1970: 0), isFavorite: true, payload: .text("same"))
        let b = ClipboardItem(createdAt: Date(timeIntervalSince1970: 100), isFavorite: false, payload: .text("same"))
        #expect(a.id != b.id)
        #expect(a.hasSameClipboardIdentity(as: b))
    }

    @Test("Items with different rich representations are different even when the plain text matches")
    func richRepresentationsDistinguish() {
        func item(rtfDigest: String?) -> ClipboardItem {
            let stored = rtfDigest.map {
                [ClipboardRepresentationDescriptor(typeIdentifier: "public.rtf", relativePath: "x.rtf", byteCount: 1, sha256: $0)]
            } ?? []
            return ClipboardItem(
                payload: .text("hello"),
                textRepresentations: ClipboardTextRepresentations(
                    declaredTypeIdentifiers: ["public.utf8-plain-text", "public.rtf"],
                    storedRepresentations: stored,
                    degradations: []
                )
            )
        }
        #expect(!item(rtfDigest: "aaa").hasSameClipboardIdentity(as: item(rtfDigest: "bbb")))
        #expect(item(rtfDigest: "aaa").hasSameClipboardIdentity(as: item(rtfDigest: "aaa")))
    }

    @Test("Character count is in Unicode scalars and only exists for text")
    func characterCount() {
        #expect(ClipboardItem(payload: .text("abc")).characterCount == 3)
        #expect(ClipboardItem(payload: .text("cafe\u{0301}")).characterCount == 5)
        #expect(ClipboardItem(payload: .text("")).characterCount == 0)
        #expect(ClipboardItem(payload: .fileURL(URL(fileURLWithPath: "/tmp/a.txt"))).characterCount == nil)
    }

    @Test("An item survives encode and decode with its payload byte for byte")
    func codableFidelity() throws {
        let text = "tabs\t, trailing space \u{00A0}, CRLF\r\n and emoji \u{1F9E1}\n"
        let item = ClipboardItem(createdAt: Date(timeIntervalSince1970: 1_700_000_000), isFavorite: true, payload: .text(text))
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.payload == .text(text))
        #expect(decoded.id == item.id)
        #expect(decoded.isFavorite)
    }
}
#endif
