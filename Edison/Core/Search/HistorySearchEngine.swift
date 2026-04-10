import Foundation

struct HistorySearchEngine {
    func filter(query: String, in items: [ClipboardItem]) -> [ClipboardItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return items }

        return items.filter { item in
            switch item.payload {
            case let .text(text):
                return text.localizedCaseInsensitiveContains(normalized)
            case let .fileURL(url):
                return url.lastPathComponent.localizedCaseInsensitiveContains(normalized)
            case .image:
                return "image screenshot".localizedCaseInsensitiveContains(normalized)
            }
        }
    }
}
