import AppKit
import CoreGraphics
import Quartz
import SwiftUI

private enum HubFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"

    var id: String { rawValue }
}

private enum HubLayoutMode: String, CaseIterable, Identifiable {
    case rail = "Shelf"
    case list = "List"
    case grid = "Grid"

    var id: String { rawValue }
}

private enum HubFocusTarget: Hashable {
    case search
}

private enum HubItemIcon {
    case system(String)
    case app(NSImage)
}

struct HubView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @FocusState private var focusedField: HubFocusTarget?
    @State private var filter: HubFilter = .all
    @State private var layoutMode: HubLayoutMode = .rail
    @State private var selectedItemID: UUID?
    @State private var newCollectionName = ""
    @State private var contentWidth: CGFloat = 0
    @State private var showQuickLook = false

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

    private var gridColumnCount: Int {
        let minimumCardWidth: CGFloat = 216
        let spacing = HubTheme.Space.x4
        let usableWidth = max(contentWidth, minimumCardWidth)
        return max(1, Int((usableWidth + spacing) / (minimumCardWidth + spacing)))
    }

    var body: some View {
        ZStack {
            HubGlassBackground()

            VStack(alignment: .leading, spacing: HubTheme.Space.x4) {
                // Resize handle
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 999)
                        .fill(HubTheme.textTertiary.opacity(0.4))
                        .frame(width: 36, height: 4)
                    Spacer()
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            appState.windowRouter?.adjustShelfHeight(by: value.translation.height)
                        }
                )
                .background(ResizeCursorView())

                header

                if items.isEmpty {
                    emptyState
                } else {
                    GeometryReader { proxy in
                        splitContentView(
                            totalWidth: proxy.size.width,
                            totalHeight: proxy.size.height
                        )
                    }
                }
            }
            .padding(HubTheme.Space.x5)

            // Undo toast
            if appState.showDeleteUndoToast {
                VStack {
                    Spacer()
                    HStack(spacing: HubTheme.Space.x3) {
                        Text("Item deleted")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(HubTheme.textPrimary)
                        Button("Undo") {
                            appState.undoDelete()
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HubTheme.accentBrand)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, HubTheme.Space.x5)
                    .padding(.vertical, HubTheme.Space.x3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(HubTheme.cardFill)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(HubTheme.glassStroke, lineWidth: 1)
                    )
                    .padding(.bottom, HubTheme.Space.x5)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.showDeleteUndoToast)
            }
        }
        .background(
            Group {
                if showQuickLook, let item = selectedItem, let url = quickLookURL(for: item) {
                    QuickLookBridge(url: url, isPresented: $showQuickLook)
                        .frame(width: 0, height: 0)
                }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            HubWindowAccessor(
                onResolveWindow: { window in
                    guard let window else { return }
                    HubShelfWindowStyle.apply(to: window)
                    appState.windowRouter?.registerHubWindow(window)
                },
                onMoveCommand: handleMoveCommand,
                onConfirmSelection: copySelectedItem,
                onDismiss: {
                    focusedField = nil
                    appState.windowRouter?.dismissHub()
                },
                onFocusSearch: {
                    focusedField = .search
                },
                onTypeSearch: { text in
                    appendToSearch(text)
                },
                onDeleteSearchCharacter: {
                    deleteSearchCharacter()
                },
                onDeleteItem: {
                    guard let selectedItem else { return }
                    appState.deleteItem(itemID: selectedItem.id)
                },
                onQuickLook: {
                    showQuickLook = true
                },
                onQuickPaste: { idx in
                    guard idx < items.count else { return }
                    appState.pasteItem(itemID: items[idx].id)
                }
            )
        )
        .ignoresSafeArea()
        .onAppear {
            appState.windowRouter?.setOpenHubAction {
                openWindow(id: "hub")
            }
            focusedField = nil
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
                        Label(mode.rawValue, systemImage: layoutSymbol(for: mode))
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

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
                .focused($focusedField, equals: .search)
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
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: HubTheme.Space.x4) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
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
                                    },
                                    badgeNumber: appState.activeQuery.isEmpty ? (index < 9 ? index + 1 : nil) : nil,
                                    collectionAccentHex: appState.collections.first(where: { $0.id == appState.selectedCollectionID })?.accentHex,
                                    onDelete: {
                                        appState.deleteItem(itemID: item.id)
                                    }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.vertical, HubTheme.Space.x1)
                        .padding(.horizontal, HubTheme.Space.x1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
                    .onChange(of: selectedItemID) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.16)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                    .onAppear {
                        if let selectedItemID {
                            proxy.scrollTo(selectedItemID, anchor: .center)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .list:
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: HubTheme.Space.x2) {
                            ForEach(items) { item in
                                HubListRowView(
                                    item: item,
                                    isSelected: item.id == selectedItem?.id,
                                    onSelect: {
                                        selectedItemID = item.id
                                    },
                                    onCopy: {
                                        appState.copyToClipboard(itemID: item.id)
                                    },
                                    onToggleFavorite: {
                                        appState.toggleFavorite(itemID: item.id)
                                    }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.vertical, HubTheme.Space.x1)
                        .padding(.horizontal, HubTheme.Space.x1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
                    .onChange(of: selectedItemID) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.16)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                    .onAppear {
                        if let selectedItemID {
                            proxy.scrollTo(selectedItemID, anchor: .center)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .grid:
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 216), spacing: HubTheme.Space.x4)], spacing: HubTheme.Space.x4) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
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
                                    },
                                    badgeNumber: appState.activeQuery.isEmpty ? (index < 9 ? index + 1 : nil) : nil,
                                    collectionAccentHex: appState.collections.first(where: { $0.id == appState.selectedCollectionID })?.accentHex,
                                    onDelete: {
                                        appState.deleteItem(itemID: item.id)
                                    }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, HubTheme.Space.x1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.vertical, HubTheme.Space.x1)
                    .clipped()
                    .onChange(of: selectedItemID) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.16)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .background(ContentWidthReader(width: $contentWidth))
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

        let step: Int
        switch layoutMode {
        case .rail:
            switch direction {
            case .left, .up:
                step = -1
            case .right, .down:
                step = 1
            @unknown default:
                step = 0
            }
        case .list:
            switch direction {
            case .left, .up:
                step = -1
            case .right, .down:
                step = 1
            @unknown default:
                step = 0
            }
        case .grid:
            switch direction {
            case .left:
                step = -1
            case .right:
                step = 1
            case .up:
                step = -gridColumnCount
            case .down:
                step = gridColumnCount
            @unknown default:
                step = 0
            }
        }

        let nextIndex = max(0, min(items.count - 1, currentIndex + step))
        guard nextIndex != currentIndex else { return }
        selectedItemID = items[nextIndex].id
    }

    private func copySelectedItem() {
        guard let selectedItem else { return }
        appState.copyToClipboard(itemID: selectedItem.id)
    }

    private func layoutSymbol(for mode: HubLayoutMode) -> String {
        switch mode {
        case .rail:
            return "square.stack.3d.down.right"
        case .list:
            return "list.bullet"
        case .grid:
            return "square.grid.2x2"
        }
    }

    private func splitContentView(totalWidth: CGFloat, totalHeight: CGFloat) -> some View {
        let railWidth = contentColumnWidth(for: totalWidth)

        return HStack(spacing: HubTheme.Space.x5) {
            contentColumn
                .frame(width: railWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)

            Divider()
                .overlay(HubTheme.dividerOnGlass)

            detailColumn
        }
        .frame(width: totalWidth, height: totalHeight, alignment: .topLeading)
        .clipped()
    }

    private func contentColumnWidth(for totalWidth: CGFloat) -> CGFloat {
        let spacing = HubTheme.Space.x5 * 2
        let dividerWidth: CGFloat = 1
        let reservedWidth = HubTheme.previewPaneWidth + spacing + dividerWidth
        return max(0, totalWidth - reservedWidth)
    }

    private func appendToSearch(_ text: String) {
        guard !text.isEmpty else { return }
        appState.activeQuery.append(text)
    }

    private func deleteSearchCharacter() {
        guard !appState.activeQuery.isEmpty else { return }
        appState.activeQuery.removeLast()
    }

    private func quickLookURL(for item: ClipboardItem) -> URL? {
        let tmp = FileManager.default.temporaryDirectory
        switch item.payload {
        case let .text(text):
            let url = tmp.appendingPathComponent("edison-ql-\(item.id).txt")
            try? text.write(to: url, atomically: true, encoding: .utf8)
            return url
        case let .image(imageData):
            let url = tmp.appendingPathComponent("edison-ql-\(item.id).png")
            try? imageData.data.write(to: url, options: .atomic)
            return url
        case let .fileURL(url):
            return url
        }
    }
}

private struct ContentWidthReader: View {
    @Binding var width: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    width = proxy.size.width
                }
                .onChange(of: proxy.size.width) { _, newValue in
                    width = newValue
                }
        }
    }
}

private struct HubListRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void

    private var accent: Color { HubTheme.accentColor(for: item) }
    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
    }

    var body: some View {
        HStack(spacing: HubTheme.Space.x3) {
            preview

            VStack(alignment: .leading, spacing: HubTheme.Space.x1) {
                Text(item.historyTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HubTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: HubTheme.Space.x2) {
                    HubMetaChip(label: item.kindLabel, icon: item.kindIcon, tint: accent)
                    Text(item.relativeTimestamp)
                        .font(.system(size: 10))
                        .foregroundStyle(HubTheme.textTertiary)
                }
            }

            Spacer(minLength: HubTheme.Space.x3)

            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.isFavorite ? HubTheme.accentBrand : HubTheme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(HubTheme.cardFillMuted)
                    )
            }
            .buttonStyle(.plain)

            Button {
                onCopy()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(HubTheme.cardFillMuted)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(HubTheme.Space.x3)
        .background(
            rowShape
                .fill(isSelected ? HubTheme.selectionFill : HubTheme.cardFill)
        )
        .overlay(
            rowShape
                .strokeBorder(isSelected ? accent.opacity(0.45) : HubTheme.glassStroke.opacity(0.55), lineWidth: 1)
        )
        .clipShape(rowShape)
        .contentShape(rowShape)
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onCopy()
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch item.payload {
        case let .image(imageData):
            if let image = NSImage(data: imageData.thumbnailData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 40)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                fallbackPreview
            }
        case .text, .fileURL:
            fallbackPreview
        }
    }

    private var fallbackPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(HubTheme.cardFillMuted)

            HubItemIconView(icon: item.kindIcon, tint: accent, size: 16)
        }
        .frame(width: 52, height: 40)
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
    let badgeNumber: Int?
    let collectionAccentHex: String?
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var accent: Color { HubTheme.accentColor(for: item) }
    private var cardSize: CGSize { HubTheme.cardSize(for: item) }
    private var previewWidth: CGFloat { max(0, cardSize.width - (HubTheme.Space.x4 * 2)) }
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
    }
    private var previewShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }

    private var barColor: Color {
        if let hex = collectionAccentHex {
            return Color(hexString: hex)
        }
        return accent
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: HubTheme.Space.x3) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(barColor)
                    .frame(width: 34, height: 4)

                preview

                VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
                    HStack(spacing: HubTheme.Space.x2) {
                        HubMetaChip(label: item.kindLabel, icon: item.kindIcon, tint: accent)
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
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let meta = item.metaFooterLabel {
                        Text(meta)
                            .font(.system(size: 10))
                            .foregroundStyle(HubTheme.textTertiary)
                            .lineLimit(1)
                    }

                    if let appName = item.sourceApplication?.localizedName {
                        Text(appName)
                            .font(.system(size: 10))
                            .foregroundStyle(HubTheme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(HubTheme.Space.x4)
            .frame(width: cardSize.width, alignment: .topLeading)
            .frame(minHeight: cardSize.height, alignment: .topLeading)

            // Source app icon badge
            if let appIcon = item.sourceApplicationIcon {
                ZStack {
                    Circle()
                        .fill(HubTheme.cardFillMuted)
                        .frame(width: 26, height: 26)
                    Image(nsImage: appIcon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .padding(HubTheme.Space.x2)
            }

            // Quick paste number badge
            if let num = badgeNumber {
                Text("\u{2318}\(num)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(HubTheme.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(HubTheme.cardFillMuted)
                    )
                    .padding(HubTheme.Space.x2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(
            cardShape
                .fill(isSelected ? HubTheme.selectionFill : HubTheme.cardFill)
        )
        .overlay(
            cardShape
                .strokeBorder(isSelected ? accent.opacity(0.45) : HubTheme.glassStroke.opacity(0.55), lineWidth: 1)
        )
        .clipShape(cardShape)
        .shadow(color: HubTheme.cardShadowAmbient(colorScheme: colorScheme), radius: 10, y: 2)
        .shadow(color: HubTheme.cardShadowKey(colorScheme: colorScheme), radius: 28, x: 0, y: 10)
        .contentShape(cardShape)
        .scaleEffect(isHovered && !isSelected ? 1.015 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.80), value: isHovered)
        .onHover { isHovered = $0 }
        .draggable(item)
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
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
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
                    .frame(width: previewWidth, height: 102)
                    .clipped()
                    .clipShape(previewShape)
            } else {
                fallbackPreview
            }
        case .text, .fileURL:
            if let hexColor = item.hexColorSwatch {
                hexColorPreview(hexColor)
            } else {
                fallbackPreview
            }
        }
    }

    private func hexColorPreview(_ color: Color) -> some View {
        ZStack {
            previewShape.fill(color)
            VStack(spacing: 4) {
                if case let .text(text) = item.payload {
                    Text(text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(color.accessibleForeground)
                }
            }
        }
        .frame(width: previewWidth, height: 84)
        .clipShape(previewShape)
    }

    private var fallbackPreview: some View {
        ZStack(alignment: .topLeading) {
            previewShape
                .fill(HubTheme.cardFillMuted)

            VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
                HubItemIconView(icon: item.kindIcon, tint: accent, size: 16)

                if case let .text(text) = item.payload {
                    Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 10))
                        .foregroundStyle(HubTheme.textSecondary)
                        .lineLimit(3)
                } else if case let .fileURL(url) = item.payload {
                    Text(url.lastPathComponent)
                        .font(.system(size: 10))
                        .foregroundStyle(HubTheme.textSecondary)
                        .lineLimit(3)
                } else {
                    Text(item.kindLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(HubTheme.textSecondary)
                }
            }
            .padding(HubTheme.Space.x3)
        }
        .frame(width: previewWidth, height: 84, alignment: .topLeading)
        .clipShape(previewShape)
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
                HubMetaChip(label: item.kindLabel, icon: item.kindIcon, tint: accent)
                HubMetaChip(label: item.relativeTimestamp, icon: .system("clock"), tint: HubTheme.textTertiary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: HubTheme.Space.x2), count: 2),
                spacing: HubTheme.Space.x2
            ) {
                HubActionButton(title: "Copy", systemImage: "doc.on.doc", tint: accent, action: onCopy)
                HubActionButton(title: "Export", systemImage: "square.and.arrow.down", tint: HubTheme.textPrimary, action: onExport)
                HubActionButton(title: "Share", systemImage: "square.and.arrow.up", tint: HubTheme.textPrimary, action: onShare)
                HubActionButton(
                    title: item.isFavorite ? "Unstar" : "Star",
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
    let icon: HubItemIcon
    let tint: Color

    var body: some View {
        HStack(spacing: HubTheme.Space.x1) {
            HubItemIconView(icon: icon, tint: tint, size: 11)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
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

private struct HubItemIconView: View {
    let icon: HubItemIcon
    let tint: Color
    let size: CGFloat

    var body: some View {
        Group {
            switch icon {
            case let .system(name):
                Image(systemName: name)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(tint)
            case let .app(image):
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size + 3, height: size + 3)
                    .clipShape(RoundedRectangle(cornerRadius: max(3, size * 0.3), style: .continuous))
            }
        }
    }
}

private struct HubActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HubTheme.Space.x1) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .center)
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

    var kindIcon: HubItemIcon {
        switch payload {
        case let .text(text):
            if let sourceApplicationIcon {
                return .app(sourceApplicationIcon)
            }
            return .system(text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("http") ? "link" : "text.quote")
        case .image:
            return .system("photo")
        case .fileURL:
            return .system("doc")
        }
    }

    var sourceApplicationIcon: NSImage? {
        guard case .text = payload else { return nil }
        return ClipboardSourceApplicationIconProvider.icon(for: sourceApplication)
    }

    var relativeTimestamp: String {
        createdAt.formatted(.relative(presentation: .named))
    }

    var metaFooterLabel: String? {
        switch payload {
        case let .text(text):
            let count = text.unicodeScalars.count
            let words = text.split(separator: " ").count
            return "\(count) chars \u{00B7} \(words) words"
        case let .image(imageData):
            if let src = CGImageSourceCreateWithData(imageData.data as CFData, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
               let w = props[kCGImagePropertyPixelWidth] as? Int,
               let h = props[kCGImagePropertyPixelHeight] as? Int {
                return "\(w) \u{00D7} \(h)"
            }
            return "Image"
        case let .fileURL(url):
            if let resources = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let size = resources.fileSize {
                return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
            return url.pathExtension.uppercased()
        }
    }

    var hexColorSwatch: Color? {
        guard case let .text(text) = payload else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4, trimmed.count <= 7, trimmed.hasPrefix("#") else { return nil }
        let hex = String(trimmed.dropFirst())
        guard hex.count == 3 || hex.count == 6 else { return nil }
        guard hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        return Color(hexString: trimmed)
    }
}

private enum ClipboardSourceApplicationIconProvider {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for sourceApplication: ClipboardSourceApplication?) -> NSImage? {
        guard let bundleIdentifier = sourceApplication?.bundleIdentifier else {
            return nil
        }

        let key = bundleIdentifier as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

private struct HubWindowAccessor: NSViewRepresentable {
    let onResolveWindow: (NSWindow?) -> Void
    let onMoveCommand: (MoveCommandDirection) -> Void
    let onConfirmSelection: () -> Void
    let onDismiss: () -> Void
    let onFocusSearch: () -> Void
    let onTypeSearch: (String) -> Void
    let onDeleteSearchCharacter: () -> Void
    let onDeleteItem: () -> Void
    let onQuickLook: () -> Void
    let onQuickPaste: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> HubWindowReaderView {
        let view = HubWindowReaderView()
        view.onResolveWindow = onResolveWindow
        view.onAttachWindow = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: HubWindowReaderView, context: Context) {
        context.coordinator.parent = self
        nsView.onResolveWindow = onResolveWindow
        nsView.resolveWindow()
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var parent: HubWindowAccessor
        private weak var window: NSWindow?
        private var keyMonitor: Any?

        init(parent: HubWindowAccessor) {
            self.parent = parent
        }

        deinit {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
        }

        func attach(to window: NSWindow?) {
            guard self.window !== window else {
                parent.onResolveWindow(window)
                return
            }

            self.window?.delegate = nil
            self.window = window
            self.window?.delegate = self
            parent.onResolveWindow(window)
            installKeyMonitorIfNeeded()
        }

        func windowDidResignKey(_ notification: Notification) {
            guard let window,
                  window.attachedSheet == nil,
                  window.childWindows?.isEmpty ?? true else { return }
            parent.onDismiss()
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard sender.attachedSheet == nil,
                  sender.childWindows?.isEmpty ?? true else { return false }
            parent.onDismiss()
            return false
        }

        private func installKeyMonitorIfNeeded() {
            guard keyMonitor == nil else { return }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let window, event.window == window else { return event }

            if let fieldEditor = window.firstResponder as? NSTextView,
               fieldEditor.isFieldEditor {
                if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
                   event.charactersIgnoringModifiers?.lowercased() == "f" {
                    parent.onFocusSearch()
                    return nil
                }

                if event.keyCode == 53 {
                    window.makeFirstResponder(nil)
                    parent.onDismiss()
                    return nil
                }

                return event
            }

            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
               event.charactersIgnoringModifiers?.lowercased() == "f" {
                parent.onFocusSearch()
                return nil
            }

            // Cmd+Delete → delete selected item
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
               event.keyCode == 51 {
                parent.onDeleteItem()
                return nil
            }

            // Cmd+1-9 → quick paste
            let quickPasteKeyCodes: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8]
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
               let idx = quickPasteKeyCodes[event.keyCode] {
                parent.onQuickPaste(idx)
                return nil
            }

            if let text = printableSearchText(from: event) {
                parent.onTypeSearch(text)
                return nil
            }

            switch event.keyCode {
            case 49: // Space → Quick Look
                parent.onQuickLook()
                return nil
            case 51, 117:
                parent.onDeleteSearchCharacter()
                return nil
            case 123:
                parent.onMoveCommand(.left)
                return nil
            case 124:
                parent.onMoveCommand(.right)
                return nil
            case 125:
                parent.onMoveCommand(.down)
                return nil
            case 126:
                parent.onMoveCommand(.up)
                return nil
            case 36, 76:
                parent.onConfirmSelection()
                return nil
            case 53:
                parent.onDismiss()
                return nil
            default:
                return event
            }
        }

        private func printableSearchText(from event: NSEvent) -> String? {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.isEmpty || modifiers == [.shift] else { return nil }
            guard let characters = event.characters, !characters.isEmpty else { return nil }
            guard characters.rangeOfCharacter(from: .controlCharacters.union(.whitespacesAndNewlines)) == nil else {
                return nil
            }
            return characters
        }
    }

    final class HubWindowReaderView: NSView {
        var onResolveWindow: (NSWindow?) -> Void = { _ in }
        var onAttachWindow: (NSWindow?) -> Void = { _ in }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindow()
        }

        func resolveWindow() {
            DispatchQueue.main.async { [weak self] in
                let window = self?.window
                self?.onAttachWindow(window)
                self?.onResolveWindow(window)
            }
        }
    }
}

// MARK: - Quick Look Bridge

private struct QuickLookBridge: NSViewRepresentable {
    let url: URL
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.open(url: url)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        if isPresented {
            context.coordinator.open(url: url)
        } else {
            QLPreviewPanel.shared()?.close()
        }
    }

    final class Coordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
        var parent: QuickLookBridge

        init(parent: QuickLookBridge) {
            self.parent = parent
        }

        func open(url: URL) {
            let panel = QLPreviewPanel.shared()!
            panel.dataSource = self
            panel.delegate = self
            panel.reloadData()
            if !panel.isVisible { panel.makeKeyAndOrderFront(nil) }
        }

        func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { 1 }

        func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
            parent.url as NSURL
        }

        func previewPanelDidClose(_ panel: QLPreviewPanel!) {
            parent.isPresented = false
        }
    }
}

// MARK: - Resize Cursor View

private struct ResizeCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { CursorView() }
    func updateNSView(_ v: NSView, context: Context) {}

    final class CursorView: NSView {
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeUpDown)
        }
    }
}

// MARK: - Color Hex String Extension

private extension Color {
    init(hexString: String) {
        let h = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        let expanded = h.count == 3 ? h.flatMap { [$0, $0] } : Array(h)
        let str = String(expanded)
        let val = UInt32(str, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8) & 0xFF) / 255,
            blue: Double(val & 0xFF) / 255,
            opacity: 1
        )
    }

    init?(hexString: String?) {
        guard let hexString else { return nil }
        self.init(hexString: hexString)
    }

    /// Returns white or black depending on which has better contrast against this color.
    var accessibleForeground: Color {
        .primary
    }
}
