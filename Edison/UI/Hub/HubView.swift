import AppKit
import SwiftUI

private enum HubFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"

    var id: String { rawValue }
}

private enum HubLayoutMode: String, CaseIterable, Identifiable {
    case list = "List"
    case grid = "Grid"

    var id: String { rawValue }
}

struct HubView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var filter: HubFilter = .all
    @State private var layoutMode: HubLayoutMode = .list
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
        VStack(spacing: 14) {
            topBar
            collectionControls

            if items.isEmpty {
                ContentUnavailableView(
                    isFilteringActive ? "No Matching Items" : "No History Yet",
                    systemImage: "doc.on.clipboard",
                    description: Text(
                        isFilteringActive
                            ? "Try a different search query or collection filter."
                            : "Copy text, image, or file to start building history."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    contentColumn
                    Divider()
                    detailColumn
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                )
            }
        }
        .padding(14)
        .navigationTitle("Edison")
        .background(
            ZStack {
                WindowIDAssigner()
                HubWindowAccessor { window in
                    appState.windowRouter?.registerHubWindow(window)
                }
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
        .sheet(isPresented: $appState.isEditorPresented) {
            EditorWindowView(imageData: appState.editorImageData) {
                appState.closeEditor()
            }
            .frame(minWidth: 840, minHeight: 560)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Picker("Filter", selection: $filter) {
                ForEach(HubFilter.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)

            Picker("Layout", selection: $layoutMode) {
                ForEach(HubLayoutMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode == .list ? "list.bullet" : "square.grid.2x2")
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Picker("Type", selection: $appState.selectedTypeFilter) {
                ForEach(HistoryItemTypeFilter.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard and screenshots", text: $appState.activeQuery)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
        }
    }

    private var collectionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("New collection", text: $newCollectionName)
                    .textFieldStyle(.roundedBorder)

                Button("Create") {
                    appState.createCollection(named: newCollectionName)
                    newCollectionName = ""
                }
                .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }

            HStack(spacing: 8) {
                Picker("Collection", selection: $appState.selectedCollectionID) {
                    Text("All Items").tag(Optional<UUID>.none)
                    ForEach(appState.collections) { collection in
                        Text(collection.name).tag(Optional(collection.id))
                    }
                }
                .pickerStyle(.menu)

                if let selectedCollectionID,
                   let selected = appState.collections.first(where: { $0.id == selectedCollectionID }) {
                    Button(role: .destructive) {
                        appState.deleteCollection(id: selected.id)
                    } label: {
                        Label("Delete \(selected.name)", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()
            }
        }
    }

    private var contentColumn: some View {
        Group {
            switch layoutMode {
            case .list:
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(items) { item in
                            HubTileView(
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
                    .padding(10)
                }
            case .grid:
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
                        ForEach(items) { item in
                            ClipboardGridItemView(
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
                    .padding(10)
                }
            }
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
        .background(Color(nsColor: .underPageBackgroundColor))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

private struct HubTileView: View {
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            previewView

            VStack(alignment: .leading, spacing: 5) {
                Text(item.historyTitle)
                    .lineLimit(2)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary)
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            if !collections.isEmpty {
                collectionMenu
            }

            Button(action: onToggleFavorite) {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
            }
            .buttonStyle(.plain)
            .foregroundStyle(item.isFavorite ? Color.yellow : Color.secondary)
            .help("Toggle favorite")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    }

    private var collectionMenu: some View {
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
            Image(systemName: "tray.full")
        }
        .menuStyle(.borderlessButton)
        .help("Add or remove from collections")
    }

    @ViewBuilder
    private var previewView: some View {
        switch item.payload {
        case .text:
            Image(systemName: "text.quote")
                .frame(width: 40, height: 32)
                .foregroundStyle(.secondary)
        case let .image(imageData):
            if let image = NSImage(data: imageData.thumbnailData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .frame(width: 40, height: 32)
                    .foregroundStyle(.secondary)
            }
        case .fileURL:
            Image(systemName: "doc")
                .frame(width: 40, height: 32)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ClipboardGridItemView: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            preview

            Text(item.historyTitle)
                .font(.subheadline)
                .lineLimit(3)

            HStack {
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onToggleFavorite()
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                }
                .buttonStyle(.plain)
                .foregroundStyle(item.isFavorite ? Color.yellow : Color.secondary)
                .help("Toggle favorite")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        .help("Select to copy back to clipboard")
    }

    @ViewBuilder
    private var preview: some View {
        switch item.payload {
        case let .image(imageData):
            if let image = NSImage(data: imageData.thumbnailData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 92)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                fallbackPreview(icon: "photo")
            }
        case .text:
            fallbackPreview(icon: "text.quote")
        case .fileURL:
            fallbackPreview(icon: "doc")
        }
    }

    private func fallbackPreview(icon: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(height: 92)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(.headline)
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

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
                    .menuStyle(.borderedButton)
                }

                Button(item.isFavorite ? "Unfavorite" : "Favorite", action: onToggleFavorite)
                    .buttonStyle(.bordered)

                Button("Export", action: onExport)
                    .buttonStyle(.bordered)

                Button("Share", action: onShare)
                    .buttonStyle(.bordered)

                Button("Copy", action: onCopy)
                    .buttonStyle(.borderedProminent)
            }

            Group {
                switch item.payload {
                case let .text(text):
                    ScrollView {
                        Text(text)
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text(url.lastPathComponent)
                            .font(.title3.weight(.semibold))
                        Text(url.path)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .padding(16)
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
}

private struct WindowIDAssigner: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            view.window?.identifier = NSUserInterfaceItemIdentifier("hub-window")
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.identifier = NSUserInterfaceItemIdentifier("hub-window")
        }
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
