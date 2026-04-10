import Foundation

enum HistoryItemTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case text = "Text"
    case image = "Image"

    var id: String { rawValue }
}

struct HistorySearchEngine {
    func filter(
        query: String,
        in items: [ClipboardItem],
        type: HistoryItemTypeFilter = .all
    ) -> [ClipboardItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            guard matchesType(item, type: type) else { return false }
            guard !normalized.isEmpty else { return true }

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

    private func matchesType(_ item: ClipboardItem, type: HistoryItemTypeFilter) -> Bool {
        switch type {
        case .all:
            return true
        case .text:
            if case .text = item.payload { return true }
            return false
        case .image:
            if case .image = item.payload { return true }
            return false
        }
    }
}
