import AppKit
import SwiftUI

private enum HubFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"

    var id: String { rawValue }
}

struct HubView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: HubFilter = .all
    @State private var newCollectionName = ""

    var items: [ClipboardItem] {
        switch filter {
        case .all: return appState.filteredItems
        case .favorites: return appState.favoriteItems
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Filter", selection: $filter) {
                    ForEach(HubFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()
            }

            collectionControls

            TextField("Search clipboard and screenshots", text: $appState.activeQuery)
                .textFieldStyle(.roundedBorder)

            if items.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "doc.on.clipboard",
                    description: Text("Copy text, image, or file to start building history.")
                )
            } else {
                List(items) { item in
                    ClipboardRowView(
                        item: item,
                        collections: appState.collections,
                        isInCollection: { collectionID in
                            appState.collectionContains(item.id, collectionID: collectionID)
                        },
                        onCopy: {
                            appState.copyToClipboard(itemID: item.id)
                        },
                        onToggleFavorite: {
                            appState.toggleFavorite(itemID: item.id)
                        },
                        onToggleCollectionMembership: { collectionID in
                            appState.toggleItem(item.id, inCollection: collectionID)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.copyToClipboard(itemID: item.id)
                    }
                }
                .listStyle(.inset)
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

    @ViewBuilder
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
            }

            HStack {
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
}

private struct ClipboardRowView: View {
    let item: ClipboardItem
    let collections: [ItemCollection]
    let isInCollection: (UUID) -> Bool
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleCollectionMembership: (UUID) -> Void

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
                    Image(systemName: "tray.full")
                }
                .menuStyle(.borderlessButton)
                .help("Add or remove from collections")
            }

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
        switch item.payload {
        case let .text(text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .image:
            return "Image / Screenshot"
        case let .fileURL(url):
            return url.lastPathComponent
        }
    }
}
