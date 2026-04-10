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
    @State private var filter: HubFilter = .all
    @State private var layoutMode: HubLayoutMode = .list

    var items: [ClipboardItem] {
        switch filter {
        case .all: return appState.filteredItems
        case .favorites: return appState.favoriteItems
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Picker("Filter", selection: $filter) {
                    ForEach(HubFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Layout", selection: $layoutMode) {
                    ForEach(HubLayoutMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode == .list ? "list.bullet" : "square.grid.2x2")
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)

                Spacer()
            }

            TextField("Search clipboard and screenshots", text: $appState.activeQuery)
                .textFieldStyle(.roundedBorder)

            if items.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "doc.on.clipboard",
                    description: Text("Copy text, image, or file to start building history.")
                )
            } else {
                switch layoutMode {
                case .list:
                    List(items) { item in
                        ClipboardRowView(item: item) {
                            appState.copyToClipboard(itemID: item.id)
                        } onToggleFavorite: {
                            appState.toggleFavorite(itemID: item.id)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.copyToClipboard(itemID: item.id)
                        }
                    }
                    .listStyle(.inset)
                case .grid:
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                            ForEach(items) { item in
                                ClipboardGridItemView(item: item) {
                                    appState.copyToClipboard(itemID: item.id)
                                } onToggleFavorite: {
                                    appState.toggleFavorite(itemID: item.id)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 2)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Edison")
        .sheet(isPresented: $appState.isEditorPresented) {
            EditorWindowView(imageData: appState.editorImageData) {
                appState.closeEditor()
            }
            .frame(minWidth: 840, minHeight: 560)
        }
    }
}

private struct ClipboardRowView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            previewView

            VStack(alignment: .leading, spacing: 4) {
                Text(primaryLabel)
                    .lineLimit(2)
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
            }
            .buttonStyle(.borderless)
            .help("Toggle favorite")

            Button {
                onCopy()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy back to clipboard")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var previewView: some View {
        switch item.payload {
        case .text:
            Image(systemName: "text.quote")
                .frame(width: 38, height: 30)
                .foregroundStyle(.secondary)
        case let .image(imageData):
            if let image = NSImage(data: imageData.thumbnailData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "photo")
                    .frame(width: 38, height: 30)
                    .foregroundStyle(.secondary)
            }
        case .fileURL:
            Image(systemName: "doc")
                .frame(width: 38, height: 30)
                .foregroundStyle(.secondary)
        }
    }

    private var primaryLabel: String {
        item.historyTitle
    }
}

private struct ClipboardGridItemView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void

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
                .help("Toggle favorite")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            onCopy()
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
            RoundedRectangle(cornerRadius: 8)
                .fill(.tertiary.opacity(0.4))
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(height: 92)
    }
}

private extension ClipboardItem {
    var historyTitle: String {
        switch payload {
        case let .text(text):
            let compact = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return compact.isEmpty ? "(empty text)" : compact
        case .image:
            return "Image / Screenshot"
        case let .fileURL(url):
            return url.lastPathComponent
        }
    }
}
