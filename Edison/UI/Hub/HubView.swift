import AppKit
import SwiftUI

private enum HubFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"

    var id: String { rawValue }
}

private enum HubLayoutMode: String, CaseIterable, Identifiable {
    case rail = "Shelf"
    case grid = "Grid"

    var id: String { rawValue }
}

struct HubView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var filter: HubFilter = .all
    @State private var layoutMode: HubLayoutMode = .rail
    @State private var selectedItemID: UUID?
    @State private var newCollectionName = ""

    private var items: [ClipboardItem] {
        switch filter {
        case .all: return appState.filteredItems
        case .favorites: return appState.favoriteItems
        }
    }

    private var selectedItem: ClipboardItem? {
        if let selectedItemID,
           let selected = items.first(where: { $0.id == selectedItemID }) {
            return selected
        }
        return items.first
    }

    private var isFilteringActive: Bool {
        !appState.activeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || appState.selectedTypeFilter != .all
            || appState.selectedCollectionID != nil
    }

    var body: some View {
        ZStack {
            HubGlassBackground()

            VStack(alignment: .leading, spacing: HubTheme.Space.x4) {
                header

                if items.isEmpty {
                    emptyState
                } else {
                    HStack(spacing: HubTheme.Space.x5) {
                        contentColumn

                        Divider()
                            .overlay(HubTheme.dividerOnGlass)

                        detailColumn
                    }
                }
            }
            .padding(HubTheme.Space.x5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            HubWindowAccessor { window in
                guard let window else { return }
                HubShelfWindowStyle.apply(to: window)
                appState.windowRouter?.registerHubWindow(window)
            }
        )
        .onAppear {
            appState.windowRouter?.setOpenHubAction {
                openWindow(id: "hub")
            }
            syncSelection()
        }
        .onChange(of: filter) { _, _ in
            syncSelection()
        }
        .onChange(of: appState.activeQuery) { _, _ in
            syncSelection()
        }
        .onChange(of: appState.selectedTypeFilter) { _, _ in
            syncSelection()
        }
        .onChange(of: appState.selectedCollectionID) { _, _ in
            syncSelection()
        }
        .onChange(of: items.map(\.id)) { _, _ in
            syncSelection()
        }
        .onMoveCommand(perform: handleMoveCommand)
        .sheet(isPresented: $appState.isEditorPresented) {
            EditorWindowView(imageData: appState.editorImageData) {
                appState.closeEditor()
            }
            .frame(minWidth: 840, minHeight: 560)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x3) {
            HStack(alignment: .center, spacing: HubTheme.Space.x3) {
                searchPill

                Picker("Filter", selection: $filter) {
                    ForEach(HubFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Picker("Type", selection: $appState.selectedTypeFilter) {
                    ForEach(HistoryItemTypeFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)

                Picker("Layout", selection: $layoutMode) {
                    ForEach(HubLayoutMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode == .rail ? "square.stack.3d.down.right" : "square.grid.2x2")
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Spacer()

                Label("Return copies selected item", systemImage: "return")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(HubTheme.textTertiary)
            }

            HStack(spacing: HubTheme.Space.x3) {
                collectionMenu

                HStack(spacing: HubTheme.Space.x2) {
                    TextField("New collection", text: $newCollectionName)
                        .textFieldStyle(.plain)
                    Button("Create") {
                        appState.createCollection(named: newCollectionName)
                        newCollectionName = ""
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(HubTheme.accentBrand)
                    .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, HubTheme.Space.x3)
                .frame(height: HubTheme.searchPillHeight)
                .background(
                    Capsule(style: .continuous)
                        .fill(HubTheme.cardFillMuted)
                )

                Spacer()
            }
        }
    }

    private var searchPill: some View {
        HStack(spacing: HubTheme.Space.x2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(HubTheme.textSecondary)
            TextField("Search clipboard and screenshots", text: $appState.activeQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, HubTheme.Space.x4)
        .frame(height: HubTheme.searchPillHeight)
        .background(
            Capsule(style: .continuous)
                .fill(HubTheme.cardFillMuted)
        )
        .frame(maxWidth: 360)
    }

    private var collectionMenu: some View {
        HStack(spacing: HubTheme.Space.x2) {
            Image(systemName: "square.stack.3d.up")
                .foregroundStyle(HubTheme.accentBrand)
            Picker("Collection", selection: $appState.selectedCollectionID) {
                Text("All Items").tag(Optional<UUID>.none)
                ForEach(appState.collections) { collection in
                    Text(collection.name).tag(Optional(collection.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            if let selectedCollectionID = appState.selectedCollectionID,
               let selected = appState.collections.first(where: { $0.id == selectedCollectionID }) {
                Button(role: .destructive) {
                    appState.deleteCollection(id: selected.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, HubTheme.Space.x3)
        .frame(height: HubTheme.searchPillHeight)
        .background(
            Capsule(style: .continuous)
                .fill(HubTheme.cardFillMuted)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x3) {
            Label(
                isFilteringActive ? "No Matching Items" : "No History Yet",
                systemImage: "doc.on.clipboard"
            )
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(HubTheme.textPrimary)

            Text(
                isFilteringActive
                    ? "Try a different search query, collection, or type filter."
                    : "Copy text, images, or files to start building the shelf."
            )
            .font(.system(size: 13))
            .foregroundStyle(HubTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(HubTheme.Space.x6)
    }

    private var contentColumn: some View {
        Group {
            switch layoutMode {
            case .rail:
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: HubTheme.Space.x4) {
                        ForEach(items) { item in
                            HubShelfCardView(
                                item: item,
                                collections: appState.collections,
                                isSelected: item.id == selectedItem?.id,
                                isInCollection: { collectionID in
                                    appState.collectionContains(item.id, collectionID: collectionID)
                                },
                                onSelect: {
                                    selectedItemID = item.id
                                },
                                onCopy: {
                                    appState.copyToClipboard(itemID: item.id)
                                },
                                onToggleFavorite: {
                                    appState.toggleFavorite(itemID: item.id)
                                },
                                onToggleCollectionMembership: { collectionID in
                                    appState.toggleItem(item.id, inCollection: collectionID)
                                },
                                onExport: {
                                    appState.exportItem(itemID: item.id)
                                },
                                onShare: {
                                    appState.shareItem(itemID: item.id)
                                }
                            )
                        }
                    }
                    .padding(.vertical, HubTheme.Space.x1)
                }
            case .grid:
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: HubTheme.Space.x4)], spacing: HubTheme.Space.x4) {
                        ForEach(items) { item in
                            HubShelfCardView(
                                item: item,
                                collections: appState.collections,
                                isSelected: item.id == selectedItem?.id,
                                isInCollection: { collectionID in
                                    appState.collectionContains(item.id, collectionID: collectionID)
                                },
                                onSelect: {
                                    selectedItemID = item.id
                                },
                                onCopy: {
                                    appState.copyToClipboard(itemID: item.id)
                                },
                                onToggleFavorite: {
                                    appState.toggleFavorite(itemID: item.id)
                                },
                                onToggleCollectionMembership: { collectionID in
                                    appState.toggleItem(item.id, inCollection: collectionID)
                                },
                                onExport: {
                                    appState.exportItem(itemID: item.id)
                                },
                                onShare: {
                                    appState.shareItem(itemID: item.id)
                                }
                            )
                        }
                    }
                    .padding(.vertical, HubTheme.Space.x1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var detailColumn: some View {
        Group {
            if let selectedItem {
                HubDetailView(
                    item: selectedItem,
                    collections: appState.collections,
                    isInCollection: { collectionID in
                        appState.collectionContains(selectedItem.id, collectionID: collectionID)
                    },
                    onCopy: {
                        appState.copyToClipboard(itemID: selectedItem.id)
                    },
                    onToggleFavorite: {
                        appState.toggleFavorite(itemID: selectedItem.id)
                    },
                    onToggleCollectionMembership: { collectionID in
                        appState.toggleItem(selectedItem.id, inCollection: collectionID)
                    },
                    onExport: {
                        appState.exportItem(itemID: selectedItem.id)
                    },
                    onShare: {
                        appState.shareItem(itemID: selectedItem.id)
                    }
                )
            }
        }
        .frame(width: HubTheme.previewPaneWidth, alignment: .topLeading)
    }

    private func syncSelection() {
        guard !items.isEmpty else {
            selectedItemID = nil
            return
        }

        if let selectedItemID,
           items.contains(where: { $0.id == selectedItemID }) {
            return
        }

        selectedItemID = items.first?.id
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard !items.isEmpty else { return }
        let currentIndex = items.firstIndex { $0.id == selectedItem?.id } ?? 0

        let nextIndex: Int
        switch direction {
        case .left, .up:
            nextIndex = max(0, currentIndex - 1)
        case .right, .down:
            nextIndex = min(items.count - 1, currentIndex + 1)
        @unknown default:
            nextIndex = currentIndex
        }

        selectedItemID = items[nextIndex].id
    }
}

private struct HubShelfCardView: View {
    let item: ClipboardItem
    let collections: [ItemCollection]
    let isSelected: Bool
    let isInCollection: (UUID) -> Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleCollectionMembership: (UUID) -> Void
    let onExport: () -> Void
    let onShare: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color { HubTheme.accentColor(for: item) }

    var body: some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x3) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(accent)
                .frame(width: 34, height: 4)

            preview

            VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
                HStack(spacing: HubTheme.Space.x2) {
                    HubMetaChip(label: item.kindLabel, icon: item.kindSymbol, tint: accent)
                    Text(item.relativeTimestamp)
                        .font(.system(size: 10))
                        .foregroundStyle(HubTheme.textTertiary)
                    Spacer()
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(HubTheme.accentBrand)
                    }
                }

                Text(item.historyTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(HubTheme.textPrimary)
                    .lineLimit(3)
            }
        }
        .padding(HubTheme.Space.x4)
        .frame(width: HubTheme.cardSize(for: item).width, height: HubTheme.cardSize(for: item).height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
                .fill(isSelected ? HubTheme.selectionFill : HubTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
                .strokeBorder(isSelected ? accent.opacity(0.45) : HubTheme.glassStroke.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: HubTheme.cardShadow(colorScheme: colorScheme), radius: 16, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous))
        .scaleEffect(isSelected ? 1.01 : 1)
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onCopy()
        }
        .contextMenu {
            Button("Copy") {
                onCopy()
            }
            Divider()
            Button(item.isFavorite ? "Remove Favorite" : "Add Favorite") {
                onToggleFavorite()
            }
            if !collections.isEmpty {
                Menu("Collections") {
                    ForEach(collections) { collection in
                        Button {
                            onToggleCollectionMembership(collection.id)
                        } label: {
                            Label(
                                collection.name,
                                systemImage: isInCollection(collection.id) ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                }
            }
            Divider()
            Button("Export") {
                onExport()
            }
            Button("Share") {
                onShare()
            }
        }
        .accessibilityLabel("\(item.kindLabel) \(item.historyTitle)")
        .accessibilityValue(item.relativeTimestamp)
    }

    @ViewBuilder
    private var preview: some View {
        switch item.payload {
        case let .image(imageData):
            if let image = NSImage(data: imageData.thumbnailData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 96)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                fallbackPreview
            }
        case .text, .fileURL:
            fallbackPreview
        }
    }

    private var fallbackPreview: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HubTheme.cardFillMuted)

            VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
                Image(systemName: item.kindSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)

                if case let .text(text) = item.payload {
                    Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 10))
                        .foregroundStyle(HubTheme.textSecondary)
                        .lineLimit(4)
                } else if case let .fileURL(url) = item.payload {
                    Text(url.lastPathComponent)
                        .font(.system(size: 10))
                        .foregroundStyle(HubTheme.textSecondary)
                        .lineLimit(4)
                } else {
                    Text(item.kindLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(HubTheme.textSecondary)
                }
            }
            .padding(HubTheme.Space.x3)
        }
        .frame(height: 96)
    }
}

private struct HubDetailView: View {
    let item: ClipboardItem
    let collections: [ItemCollection]
    let isInCollection: (UUID) -> Bool
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleCollectionMembership: (UUID) -> Void
    let onExport: () -> Void
    let onShare: () -> Void

    private var accent: Color { HubTheme.accentColor(for: item) }

    var body: some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x4) {
            VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
                Text("Selected Item")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HubTheme.textPrimary)

                Text(item.historyTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(HubTheme.textSecondary)
                    .lineLimit(3)
            }

            HStack(spacing: HubTheme.Space.x2) {
                HubMetaChip(label: item.kindLabel, icon: item.kindSymbol, tint: accent)
                HubMetaChip(label: item.relativeTimestamp, icon: "clock", tint: HubTheme.textTertiary)
            }

            HStack(spacing: HubTheme.Space.x2) {
                HubActionButton(title: "Copy", systemImage: "doc.on.doc", tint: accent, action: onCopy)
                HubActionButton(title: "Export", systemImage: "square.and.arrow.down", tint: HubTheme.textPrimary, action: onExport)
                HubActionButton(title: "Share", systemImage: "square.and.arrow.up", tint: HubTheme.textPrimary, action: onShare)
                HubActionButton(
                    title: item.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: item.isFavorite ? "star.fill" : "star",
                    tint: item.isFavorite ? HubTheme.accentBrand : HubTheme.textPrimary,
                    action: onToggleFavorite
                )
            }

            if !collections.isEmpty {
                Menu {
                    ForEach(collections) { collection in
                        Button {
                            onToggleCollectionMembership(collection.id)
                        } label: {
                            Label(
                                collection.name,
                                systemImage: isInCollection(collection.id) ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                } label: {
                    Label("Collections", systemImage: "square.stack.3d.up")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(HubTheme.textPrimary)
                        .padding(.horizontal, HubTheme.Space.x3)
                        .frame(height: 32)
                        .background(
                            Capsule(style: .continuous)
                                .fill(HubTheme.cardFillMuted)
                        )
                }
                .menuStyle(.borderlessButton)
            }

            detailPreview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var detailPreview: some View {
        Group {
            switch item.payload {
            case let .text(text):
                ScrollView {
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(HubTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            case let .image(imageData):
                if let image = NSImage(data: imageData.data) {
                    GeometryReader { proxy in
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                } else {
                    ContentUnavailableView("Image Preview Unavailable", systemImage: "photo")
                }
            case let .fileURL(url):
                VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HubTheme.textPrimary)
                    Text(url.path)
                        .font(.system(size: 11))
                        .foregroundStyle(HubTheme.textSecondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(HubTheme.Space.x4)
        .background(
            RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
                .fill(HubTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
                .strokeBorder(HubTheme.glassStroke.opacity(0.55), lineWidth: 1)
        )
    }
}

private struct HubMetaChip: View {
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: HubTheme.Space.x1) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, HubTheme.Space.x2)
        .frame(height: 24)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}

private struct HubActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .padding(.horizontal, HubTheme.Space.x3)
        .frame(height: 32)
        .background(
            Capsule(style: .continuous)
                .fill(HubTheme.cardFillMuted)
        )
    }
}

private extension ClipboardItem {
    var historyTitle: String {
        switch payload {
        case let .text(text):
            let compact = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return compact.isEmpty ? "Text item" : compact
        case .image:
            return "Image / Screenshot"
        case let .fileURL(url):
            return url.lastPathComponent
        }
    }

    var kindLabel: String {
        switch payload {
        case let .text(text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("http") ? "Link" : "Text"
        case .image:
            return "Image"
        case .fileURL:
            return "File"
        }
    }

    var kindSymbol: String {
        switch payload {
        case let .text(text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("http") ? "link" : "text.quote"
        case .image:
            return "photo"
        case .fileURL:
            return "doc"
        }
    }

    var relativeTimestamp: String {
        createdAt.formatted(.relative(presentation: .named))
    }
}

private struct HubWindowAccessor: NSViewRepresentable {
    let onResolveWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> HubWindowReaderView {
        let view = HubWindowReaderView()
        view.onResolveWindow = onResolveWindow
        return view
    }

    func updateNSView(_ nsView: HubWindowReaderView, context: Context) {
        nsView.onResolveWindow = onResolveWindow
        nsView.resolveWindow()
    }

    final class HubWindowReaderView: NSView {
        var onResolveWindow: (NSWindow?) -> Void = { _ in }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindow()
        }

        func resolveWindow() {
            DispatchQueue.main.async { [weak self] in
                self?.onResolveWindow(self?.window)
            }
        }
    }
}
