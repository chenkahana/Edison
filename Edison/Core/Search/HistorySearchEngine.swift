import Foundation

enum HistoryItemTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case text = "Text"
    case link = "Links"
    case image = "Image"
    case file = "Files"
    case color = "Colours"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .all: return "tray.full"
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        case .color: return "paintpalette"
        }
    }

    /// Accepts the words people type after `type:`.
    init?(token: String) {
        switch token.lowercased() {
        case "text", "txt", "code": self = .text
        case "link", "links", "url", "urls": self = .link
        case "image", "images", "img", "screenshot", "screenshots": self = .image
        case "file", "files": self = .file
        case "color", "colour", "colors", "colours": self = .color
        default: return nil
        }
    }

    func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all:
            return true
        case .text:
            if case .text = item.payload { return true }
            return false
        case .image:
            if case .image = item.payload { return true }
            return false
        case .file:
            if case .fileURL = item.payload { return true }
            return false
        case .link:
            return item.contentKind == .link
        case .color:
            return item.contentKind == .color
        }
    }
}

/// A parsed Hub query: free-text words plus optional `app:` and `type:` tokens.
struct HistorySearchQuery: Equatable {
    var terms: [String] = []
    var applicationTerms: [String] = []
    var type: HistoryItemTypeFilter?

    var isEmpty: Bool { terms.isEmpty && applicationTerms.isEmpty && type == nil }

    init(_ raw: String) {
        for token in raw.split(whereSeparator: \.isWhitespace).map(String.init) {
            let lower = token.lowercased()
            if lower.hasPrefix("app:"), token.count > 4 {
                applicationTerms.append(String(token.dropFirst(4)))
            } else if lower.hasPrefix("type:"), let type = HistoryItemTypeFilter(token: String(token.dropFirst(5))) {
                self.type = type
            } else {
                terms.append(token)
            }
        }
    }
}

struct HistorySearchEngine {
    func filter(
        query: String,
        in items: [ClipboardItem],
        type: HistoryItemTypeFilter = .all
    ) -> [ClipboardItem] {
        let parsed = HistorySearchQuery(query)
        return items.filter { item in
            guard type.matches(item) else { return false }
            if let tokenType = parsed.type, !tokenType.matches(item) { return false }
            guard parsed.applicationTerms.allSatisfy({ matchesApplication(item, term: $0) }) else { return false }
            return parsed.terms.allSatisfy { matchesContent(item, term: $0) }
        }
    }

    private func matchesApplication(_ item: ClipboardItem, term: String) -> Bool {
        guard let application = item.sourceApplication else { return false }
        return (application.localizedName ?? "").localizedCaseInsensitiveContains(term)
            || application.bundleIdentifier.localizedCaseInsensitiveContains(term)
    }

    private func matchesContent(_ item: ClipboardItem, term: String) -> Bool {
        switch item.payload {
        case let .text(text):
            return text.localizedCaseInsensitiveContains(term)
        case let .fileURL(url):
            return url.lastPathComponent.localizedCaseInsensitiveContains(term)
        case .image:
            return "image screenshot".localizedCaseInsensitiveContains(term)
        }
    }
}
