import AppKit
import CoreGraphics
import Quartz
import SwiftUI

enum HubFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"

    var id: String { rawValue }
}

enum HubLayoutMode: String, CaseIterable, Identifiable {
    case rail = "Shelf"
    case list = "List"
    case grid = "Grid"

    var id: String { rawValue }
}

enum HubFocusTarget: Hashable {
    case search
}

enum HubItemIcon {
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
    @State private var showAccessibilityAlert = false

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
                onConfirmSelection: {
                    pasteSelectedItem()
                },
                onDismiss: {
                    focusedField = nil
                    appState.dismissHub()
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
            appState.windowRouter?.setOpenEditorAction {
                openWindow(id: "editor")
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
        .onChange(of: appState.accessibilityDenied) { _, isDenied in
            guard isDenied else { return }
            showAccessibilityAlert = true
        }
        .onMoveCommand(perform: handleMoveCommand)
        .alert("Allow Accessibility Access", isPresented: $showAccessibilityAlert) {
            Button("Open Accessibility Settings") {
                appState.requestAccessibilityAccess()
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Edison needs Accessibility access to paste into other apps. Approve Edison in the macOS Accessibility settings, then retry the paste.")
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x4) {
            HubHeaderView(
                filter: $filter,
                layoutMode: $layoutMode,
                newCollectionName: $newCollectionName,
                focusedField: $focusedField
            )

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
                                            pasteSelectedItem(selecting: item.id)
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
                                            pasteSelectedItem(selecting: item.id)
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
                                            pasteSelectedItem(selecting: item.id)
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

    private func pasteSelectedItem(selecting itemID: UUID? = nil) {
        if let itemID {
            selectedItemID = itemID
        }

        appState.pasteSelection(from: items, selectedItemID: itemID ?? selectedItemID)
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

// MARK: - HubListRowView

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

// MARK: - HubShelfCardView

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

// MARK: - HubImagePreviewView

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

// MARK: - HubCardFooter

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

// MARK: - Text Formatting Utilities

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

// MARK: - ClipboardItem Extensions

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
