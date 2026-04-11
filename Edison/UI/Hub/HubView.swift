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
    @State private var contentHeight: CGFloat = 0
    @State private var showQuickLook = false
    @State private var hubOpenSequence = 0

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
        let minimumCardWidth = HubTheme.cardSide(for: contentHeight)
        let spacing = HubTheme.Space.x4
        let usableWidth = max(contentWidth, minimumCardWidth)
        return max(1, Int((usableWidth + spacing) / (minimumCardWidth + spacing)))
    }

    var body: some View {
        ZStack {
            HubGlassBackground()

            mainContent
            undoToastOverlay
            captureErrorOverlay
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
                onConfirmSelection: pasteSelectedItem,
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
        .onReceive(NotificationCenter.default.publisher(for: .edisonHubWillOpen)) { _ in
            focusedField = nil
            showQuickLook = false
            resetSelectionToLatest()
            hubOpenSequence += 1
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

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x4) {
            header

            if items.isEmpty {
                emptyState
            } else {
                contentColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(HubTheme.Space.x5)
    }

    @ViewBuilder
    private var undoToastOverlay: some View {
        if appState.showDeleteUndoToast {
            VStack {
                Spacer()
                HubToastView(
                    title: "Item deleted",
                    buttonTitle: "Undo",
                    action: appState.undoDelete
                )
                .padding(.bottom, HubTheme.Space.x5)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.showDeleteUndoToast)
        }
    }

    @ViewBuilder
    private var captureErrorOverlay: some View {
        if let errorMessage = appState.captureError {
            VStack {
                HubCaptureErrorBanner(
                    message: errorMessage,
                    dismiss: {
                        appState.captureError = nil
                    }
                )
                .padding(.horizontal, HubTheme.Space.x5)
                .padding(.top, HubTheme.Space.x5)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.captureError != nil)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: HubTheme.Space.x3) {
                searchPill
                    .frame(minWidth: 240, idealWidth: 320, maxWidth: 360)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                trailingControls
            }

            VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
                HStack(alignment: .center, spacing: HubTheme.Space.x3) {
                    searchPill
                    Spacer(minLength: 0)
                    filterControls
                }

                collectionControls
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterControls: some View {
        HStack(alignment: .center, spacing: HubTheme.Space.x2) {
            filterPicker
                .frame(width: 112)
            typePicker
                .frame(width: 162)
            layoutPicker
                .frame(width: 150)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var collectionControls: some View {
        HStack(alignment: .center, spacing: HubTheme.Space.x2) {
            collectionMenu
                .frame(width: 134)
            newCollectionComposer
                .frame(width: 198)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var trailingControls: some View {
        HStack(alignment: .center, spacing: HubTheme.Space.x2) {
            filterControls
            collectionControls
        }
        .fixedSize(horizontal: true, vertical: false)
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
        .frame(maxWidth: .infinity)
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(HubFilter.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    private var typePicker: some View {
        Picker("Type", selection: $appState.selectedTypeFilter) {
            ForEach(HistoryItemTypeFilter.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    private var layoutPicker: some View {
        Picker("Layout", selection: $layoutMode) {
            ForEach(HubLayoutMode.allCases) { mode in
                Label(mode.rawValue, systemImage: layoutSymbol(for: mode))
                    .tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    private var newCollectionComposer: some View {
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
        GeometryReader { proxy in
            let cardSide = HubTheme.cardSide(for: proxy.size.height)

            Group {
                switch layoutMode {
                case .rail:
                    ScrollViewReader { listProxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: HubTheme.Space.x4) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                                    HubShelfCardView(
                                        item: item,
                                        sideLength: cardSide,
                                        collections: appState.collections,
                                        isSelected: item.id == selectedItem?.id,
                                        isInCollection: { collectionID in
                                            appState.collectionContains(item.id, collectionID: collectionID)
                                        },
                                        onSelect: {
                                            selectedItemID = item.id
                                        },
                                        onActivate: {
                                            appState.pasteItem(itemID: item.id)
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
                        .clipped()
                        .onChange(of: selectedItemID) { _, newValue in
                            scrollSelection(with: listProxy, to: newValue, in: .rail)
                        }
                        .onChange(of: hubOpenSequence) { _, _ in
                            scrollSelection(with: listProxy, to: selectedItemID, in: .rail, opening: true)
                        }
                        .onAppear {
                            scrollSelection(with: listProxy, to: selectedItemID, in: .rail, opening: true)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                case .list:
                    ScrollViewReader { listProxy in
                        ScrollView {
                            LazyVStack(spacing: HubTheme.Space.x2) {
                                ForEach(items) { item in
                                    HubListRowView(
                                        item: item,
                                        collections: appState.collections,
                                        isSelected: item.id == selectedItem?.id,
                                        isInCollection: { collectionID in
                                            appState.collectionContains(item.id, collectionID: collectionID)
                                        },
                                        onSelect: {
                                            selectedItemID = item.id
                                        },
                                        onActivate: {
                                            appState.pasteItem(itemID: item.id)
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
                            scrollSelection(with: listProxy, to: newValue, in: .list)
                        }
                        .onChange(of: hubOpenSequence) { _, _ in
                            scrollSelection(with: listProxy, to: selectedItemID, in: .list, opening: true)
                        }
                        .onAppear {
                            scrollSelection(with: listProxy, to: selectedItemID, in: .list, opening: true)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                case .grid:
                    ScrollViewReader { listProxy in
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: cardSide), spacing: HubTheme.Space.x4)],
                                spacing: HubTheme.Space.x4
                            ) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                                    HubShelfCardView(
                                        item: item,
                                        sideLength: cardSide,
                                        collections: appState.collections,
                                        isSelected: item.id == selectedItem?.id,
                                        isInCollection: { collectionID in
                                            appState.collectionContains(item.id, collectionID: collectionID)
                                        },
                                        onSelect: {
                                            selectedItemID = item.id
                                        },
                                        onActivate: {
                                            appState.pasteItem(itemID: item.id)
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
                        .clipped()
                        .onChange(of: selectedItemID) { _, newValue in
                            scrollSelection(with: listProxy, to: newValue, in: .grid)
                        }
                        .onChange(of: hubOpenSequence) { _, _ in
                            scrollSelection(with: listProxy, to: selectedItemID, in: .grid, opening: true)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .background(ContentSizeReader(width: $contentWidth, height: $contentHeight))
        }
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

    private func resetSelectionToLatest() {
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

    private func pasteSelectedItem() {
        guard let selectedItem else { return }
        appState.pasteItem(itemID: selectedItem.id)
    }

    private func scrollSelection(
        with proxy: ScrollViewProxy,
        to itemID: UUID?,
        in layoutMode: HubLayoutMode,
        opening: Bool = false
    ) {
        guard let itemID else { return }

        let isLeadingItem = itemID == items.first?.id
        let anchor: UnitPoint
        switch layoutMode {
        case .rail:
            anchor = (opening || isLeadingItem) ? .leading : .center
        case .list:
            anchor = (opening || isLeadingItem) ? .top : .center
        case .grid:
            anchor = (opening || isLeadingItem) ? .topLeading : .center
        }

        if opening {
            proxy.scrollTo(itemID, anchor: anchor)
        } else {
            withAnimation(.easeInOut(duration: 0.16)) {
                proxy.scrollTo(itemID, anchor: anchor)
            }
        }
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
            guard let data = try? ImageStore.load(relativePath: imageData.imagePath),
                  (try? data.write(to: url, options: .atomic)) != nil else {
                return nil
            }
            return url
        case let .fileURL(url):
            return url
        }
    }
}

private struct ContentSizeReader: View {
    @Binding var width: CGFloat
    @Binding var height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    width = proxy.size.width
                    height = proxy.size.height
                }
                .onChange(of: proxy.size) { _, newValue in
                    width = newValue.width
                    height = newValue.height
                }
        }
    }
}

private struct HubListRowView: View {
    let item: ClipboardItem
    let collections: [ItemCollection]
    let isSelected: Bool
    let isInCollection: (UUID) -> Bool
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleCollectionMembership: (UUID) -> Void
    let onExport: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    private var accent: Color { HubTheme.accentColor(for: item) }
    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
    }

    var body: some View {
        HStack(alignment: .center, spacing: HubTheme.Space.x3) {
            if case .image = item.payload {
                preview
            }
            VStack(alignment: .leading, spacing: HubTheme.Space.x1) {
                if let primaryText = item.primaryContentText {
                    HubClipboardTextView(
                        text: primaryText,
                        fontSize: 13,
                        fontWeight: .medium,
                        lineLimit: item.isFilePayload ? 3 : 2
                    )
                        .lineLimit(item.isFilePayload ? 3 : 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HubCardFooter(item: item)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(HubTheme.Space.x3)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
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
            onActivate()
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
        .accessibilityLabel(item.accessibilityTitle)
        .accessibilityValue(item.compactRelativeTimestamp)
    }

    @ViewBuilder
    private var preview: some View {
        if case let .image(imageData) = item.payload {
            HubImagePreviewView(
                dataPath: imageData.thumbnailPath,
                fallbackSymbol: item.fallbackPreviewSymbol,
                accent: accent,
                cornerRadius: 12,
                padding: HubTheme.Space.x1,
                fixedSize: CGSize(width: 72, height: 52)
            )
        }
    }

    private var fallbackPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HubTheme.cardFillMuted)

            HubItemIconView(icon: .system(item.fallbackPreviewSymbol), tint: accent, size: 16)
        }
        .frame(width: 72, height: 52)
    }
}

private struct HubShelfCardView: View {
    let item: ClipboardItem
    let sideLength: CGFloat
    let collections: [ItemCollection]
    let isSelected: Bool
    let isInCollection: (UUID) -> Bool
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleCollectionMembership: (UUID) -> Void
    let onExport: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color { HubTheme.accentColor(for: item) }
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
    }
    private var previewShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }
    private var textLineLimit: Int {
        max(3, Int((sideLength - 48) / 22))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x3) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HubCardFooter(item: item)
        }
        .padding(HubTheme.Space.x4)
        .frame(width: sideLength, height: sideLength, alignment: .topLeading)
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
        .clipped()
        .draggable(item)
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onActivate()
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
        .accessibilityLabel(item.accessibilityTitle)
        .accessibilityValue(item.compactRelativeTimestamp)
    }

    @ViewBuilder
    private var content: some View {
        switch item.payload {
        case let .text(text):
            HubClipboardTextView(
                text: text,
                fontSize: 15,
                fontWeight: .medium,
                lineLimit: textLineLimit
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case let .image(imageData):
            HubImagePreviewView(
                dataPath: imageData.thumbnailPath,
                fallbackSymbol: item.fallbackPreviewSymbol,
                accent: accent,
                cornerRadius: 14,
                padding: HubTheme.Space.x2
            )
        case let .fileURL(url):
            VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HubTheme.textPrimary)
                    .lineLimit(2)
                Text(url.path)
                    .font(.system(size: 12))
                    .foregroundStyle(HubTheme.textSecondary)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var fallbackPreview: some View {
        ZStack {
            previewShape
                .fill(HubTheme.cardFillMuted)

            HubItemIconView(icon: .system(item.fallbackPreviewSymbol), tint: accent, size: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(previewShape)
    }
}

private struct HubClipboardTextView: View {
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let lineLimit: Int?

    private let content: HubStructuredTextContent

    init(text: String, fontSize: CGFloat, fontWeight: Font.Weight, lineLimit: Int?) {
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.lineLimit = lineLimit
        self.content = HubStructuredTextFormatter.content(for: text)
    }

    var body: some View {
        Group {
            switch content {
            case let .plain(text):
                Text(text)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundStyle(HubTheme.textPrimary)
            case let .json(text):
                Text(text)
                    .font(.system(size: max(fontSize - 1, 12), weight: .regular, design: .monospaced))
                    .foregroundStyle(HubTheme.textPrimary)
            case let .markdown(text):
                Text(text)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundStyle(HubTheme.textPrimary)
                    .tint(HubTheme.accentBrand)
            }
        }
        .multilineTextAlignment(.leading)
        .lineLimit(lineLimit)
    }
}

private struct HubImagePreviewView: View {
    let dataPath: String
    let fallbackSymbol: String
    let accent: Color
    let cornerRadius: CGFloat
    let padding: CGFloat
    var fixedSize: CGSize? = nil

    private var previewShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            previewShape
                .fill(HubTheme.cardFillMuted)

            if let imageData = try? ImageStore.load(relativePath: dataPath),
               let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(padding)
            } else {
                HubItemIconView(icon: .system(fallbackSymbol), tint: accent, size: 20)
            }
        }
        .frame(
            width: fixedSize?.width,
            height: fixedSize?.height
        )
        .frame(maxWidth: fixedSize == nil ? .infinity : nil, maxHeight: fixedSize == nil ? .infinity : nil)
        .clipShape(previewShape)
    }
}

private struct HubCardFooter: View {
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: HubTheme.Space.x2) {
            if let appIcon = item.sourceApplicationIcon {
                HubItemIconView(icon: .app(appIcon), tint: HubTheme.textTertiary, size: 16)
            }
            Text(item.compactRelativeTimestamp)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HubTheme.textTertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
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

enum HubStructuredTextFormatter {
    static func content(for text: String) -> HubStructuredTextContent {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plain("Text item") }

        if let json = prettyPrintedJSON(from: trimmed) {
            return .json(json)
        }

        if looksLikeMarkdown(trimmed),
           let markdown = attributedMarkdown(from: trimmed) {
            return .markdown(markdown)
        }

        return .plain(trimmed)
    }

    static func prettyPrintedJSON(from text: String) -> String? {
        guard let firstCharacter = text.first,
              firstCharacter == "{" || firstCharacter == "[" else {
            return nil
        }

        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let prettyText = String(data: prettyData, encoding: .utf8) else {
            return nil
        }

        return prettyText
    }

    private static func attributedMarkdown(from text: String) -> AttributedString? {
        try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )
    }

    private static func looksLikeMarkdown(_ text: String) -> Bool {
        let indicators = [
            "```",
            "# ",
            "## ",
            "### ",
            "> ",
            "- ",
            "* ",
            "`",
            "**",
            "__",
            "](",
            "\n1. "
        ]

        return indicators.contains { text.contains($0) }
    }
}

enum HubStructuredTextContent {
    case plain(String)
    case json(String)
    case markdown(AttributedString)
}

enum HubRelativeTimeFormatter {
    static func string(for date: Date, relativeTo reference: Date = .now) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: reference)

        if let day = components.day, day >= 1 {
            return "\(day)d"
        }
        if let hour = components.hour, hour >= 1 {
            return "\(hour)h"
        }
        if let minute = components.minute, minute >= 1 {
            return "\(minute)m"
        }
        return "now"
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

    var primaryContentText: String? {
        switch payload {
        case let .text(text):
            let compact = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return compact.isEmpty ? "Text item" : compact
        case .image:
            return nil
        case let .fileURL(url):
            return url.path
        }
    }

    var isFilePayload: Bool {
        if case .fileURL = payload {
            return true
        }
        return false
    }

    var fallbackPreviewSymbol: String {
        switch payload {
        case .text:
            return "text.alignleft"
        case .image:
            return "photo"
        case .fileURL:
            return "doc"
        }
    }

    var sourceApplicationIcon: NSImage? {
        ClipboardSourceApplicationIconProvider.icon(for: sourceApplication)
    }

    var compactRelativeTimestamp: String {
        HubRelativeTimeFormatter.string(for: createdAt)
    }

    var accessibilityTitle: String {
        switch payload {
        case let .text(text):
            let compact = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return compact.isEmpty ? "Clipboard text" : compact
        case .image:
            return "Clipboard image"
        case let .fileURL(url):
            return url.lastPathComponent
        }
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
        view.onAttachWindow = { [weak coordinator = context.coordinator] hostView, window in
            coordinator?.attach(view: hostView, to: window)
        }
        view.onKeyDown = { [weak coordinator = context.coordinator] event in
            coordinator?.handleKeyDown(event) ?? false
        }
        return view
    }

    func updateNSView(_ nsView: HubWindowReaderView, context: Context) {
        context.coordinator.parent = self
        nsView.onResolveWindow = onResolveWindow
        nsView.onKeyDown = { [weak coordinator = context.coordinator] event in
            coordinator?.handleKeyDown(event) ?? false
        }
        nsView.resolveWindow()
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var parent: HubWindowAccessor
        private weak var window: NSWindow?
        private weak var readerView: HubWindowReaderView?

        init(parent: HubWindowAccessor) {
            self.parent = parent
        }

        func attach(view: HubWindowReaderView, to window: NSWindow?) {
            guard self.window !== window || self.readerView !== view else {
                parent.onResolveWindow(window)
                return
            }

            self.window?.delegate = nil
            self.readerView = view
            self.window = window
            self.window?.delegate = self
            parent.onResolveWindow(window)
            focusKeyboardHost()
        }

        func windowDidBecomeKey(_ notification: Notification) {
            focusKeyboardHost()
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

        private func focusKeyboardHost() {
            guard let window,
                  let readerView else { return }

            DispatchQueue.main.async {
                guard window.isKeyWindow else { return }
                window.makeFirstResponder(readerView)
            }
        }

        func handleKeyDown(_ event: NSEvent) -> Bool {
            guard let window,
                  event.window == window || window.isKeyWindow else { return false }

            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
               event.charactersIgnoringModifiers?.lowercased() == "f" {
                parent.onFocusSearch()
                return true
            }

            // Cmd+Delete → delete selected item
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
               event.keyCode == 51 {
                parent.onDeleteItem()
                return true
            }

            // Cmd+1-9 → quick paste
            let quickPasteKeyCodes: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8]
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
               let idx = quickPasteKeyCodes[event.keyCode] {
                parent.onQuickPaste(idx)
                return true
            }

            if let text = printableSearchText(from: event) {
                parent.onTypeSearch(text)
                return true
            }

            switch event.keyCode {
            case 49: // Space → Quick Look
                parent.onQuickLook()
                return true
            case 51, 117:
                parent.onDeleteSearchCharacter()
                return true
            case 123:
                parent.onMoveCommand(.left)
                return true
            case 124:
                parent.onMoveCommand(.right)
                return true
            case 125:
                parent.onMoveCommand(.down)
                return true
            case 126:
                parent.onMoveCommand(.up)
                return true
            case 36, 76:
                parent.onConfirmSelection()
                return true
            case 53:
                parent.onDismiss()
                return true
            default:
                return false
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
        var onAttachWindow: (HubWindowReaderView, NSWindow?) -> Void = { _, _ in }
        var onKeyDown: (NSEvent) -> Bool = { _ in false }

        override var acceptsFirstResponder: Bool { true }
        override var canBecomeKeyView: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindow()
        }

        override func keyDown(with event: NSEvent) {
            if onKeyDown(event) {
                return
            }
            super.keyDown(with: event)
        }

        func resolveWindow() {
            let window = self.window
            onAttachWindow(self, window)
            onResolveWindow(window)
        }
    }
}

private struct HubToastView: View {
    let title: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: HubTheme.Space.x3) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(HubTheme.textPrimary)
            Button(buttonTitle, action: action)
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
    }
}

private struct HubCaptureErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: HubTheme.Space.x3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(HubTheme.textPrimary)
                .lineLimit(1)
            Spacer()
            Button("Screen Recording") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                )
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(HubTheme.accentBrand)
            .buttonStyle(.plain)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(HubTheme.textSecondary)
            }
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
