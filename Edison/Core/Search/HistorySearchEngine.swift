import Foundation

enum HistoryItemTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case text = "Text"
    case code = "Code"
    case terminal = "Terminal"
    case link = "Links"
    case image = "Image"
    case file = "Files"
    case color = "Colours"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .all: return "tray.full"
        case .text: return "text.alignleft"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .terminal: return "terminal"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        case .color: return "paintpalette"
        }
    }

    /// Accepts the words people type after `type:`.
    init?(token: String) {
        switch token.lowercased() {
        case "text", "txt": self = .text
        case "code": self = .code
        case "terminal", "shell", "log", "logs": self = .terminal
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
        case .code:
            return item.contentKind == .code
        case .terminal:
            return item.contentKind == .terminal
        case .link:
            return item.contentKind == .link
        case .color:
            return item.contentKind == .color
        }
    }
}

/// A parsed Hub query: free-text words plus optional `app:`, `type:` and `topic:` tokens.
struct HistorySearchQuery: Equatable {
    var terms: [String] = []
    var applicationTerms: [String] = []
    /// Topic tags, with spaces written as hyphens (`topic:version-control`).
    var topicTerms: [String] = []
    var type: HistoryItemTypeFilter?

    var isEmpty: Bool { terms.isEmpty && applicationTerms.isEmpty && topicTerms.isEmpty && type == nil }

    /// The token that filters to a topic, as the Hub's Topics menu types it.
    static func token(forTopic topic: String) -> String {
        "topic:" + topic.replacingOccurrences(of: " ", with: "-")
    }

    init(_ raw: String) {
        for token in raw.split(whereSeparator: \.isWhitespace).map(String.init) {
            let lower = token.lowercased()
            if lower.hasPrefix("app:"), token.count > 4 {
                applicationTerms.append(String(token.dropFirst(4)))
            } else if lower.hasPrefix("topic:"), token.count > 6 {
                topicTerms.append(String(token.dropFirst(6)).replacingOccurrences(of: "-", with: " "))
            } else if lower.hasPrefix("type:"), let type = HistoryItemTypeFilter(token: String(token.dropFirst(5))) {
                self.type = type
            } else {
                terms.append(token)
            }
        }
    }
}

struct HistorySearchEngine {
    /// Items matching every word, in history order: those whose own text (or file name, or text
    /// read from the image) has every word come first, then those matched partly through topic tags.
    /// `relatedItemIDs` (search by meaning, best first) follow, if they pass the same filters and
    /// tokens but didn't match the words.
    func filter(
        query: String,
        in items: [ClipboardItem],
        type: HistoryItemTypeFilter = .all,
        relatedItemIDs: [UUID] = []
    ) -> [ClipboardItem] {
        let parsed = HistorySearchQuery(query)
        let candidates = items.filter { item in
            guard type.matches(item) else { return false }
            if let tokenType = parsed.type, !tokenType.matches(item) { return false }
            guard parsed.applicationTerms.allSatisfy({ matchesApplication(item, term: $0) }) else { return false }
            return parsed.topicTerms.allSatisfy { topic in item.topics.contains { $0.caseInsensitiveCompare(topic) == .orderedSame } }
        }
        var exact: [ClipboardItem] = []
        var viaTopics: [ClipboardItem] = []
        var unmatched: [UUID: ClipboardItem] = [:]
        for item in candidates {
            if parsed.terms.allSatisfy({ matchesContent(item, term: $0) }) {
                exact.append(item)
            } else if parsed.terms.allSatisfy({ matchesContent(item, term: $0) || matchesTopics(item, term: $0) }) {
                viaTopics.append(item)
            } else {
                unmatched[item.id] = item
            }
        }
        let related = parsed.terms.isEmpty ? [] : relatedItemIDs.compactMap { unmatched[$0] }
        return exact + viaTopics + related
    }

    private func matchesTopics(_ item: ClipboardItem, term: String) -> Bool {
        item.topics.contains { $0.localizedCaseInsensitiveContains(term) }
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
                || item.imageSearchText.contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }
}
