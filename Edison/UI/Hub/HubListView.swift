import AppKit
import SwiftUI

// MARK: - HubListView

/// The vertical-scrolling list layout mode.
struct HubListView: View {
    let items: [ClipboardItem]
    let selectedItem: ClipboardItem?
    let hubOpenSequence: Int
    let collections: [ItemCollection]
    let isInCollection: (UUID, UUID) -> Bool
    let onSelect: (UUID) -> Void
    let onActivate: (UUID) -> Void
    let onCopy: (UUID) -> Void
    let onToggleFavorite: (UUID) -> Void
    let onToggleCollectionMembership: (UUID, UUID) -> Void
    let onExport: (UUID) -> Void
    let onShare: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let scrollToSelection: (ScrollViewProxy, UUID?, Bool) -> Void

    var body: some View {
        ScrollViewReader { listProxy in
            ScrollView {
                LazyVStack(spacing: HubTheme.Space.x2) {
                    ForEach(items) { item in
                        HubListRowView(
                            item: item,
                            collections: collections,
                            isSelected: item.id == selectedItem?.id,
                            isInCollection: { collectionID in
                                isInCollection(item.id, collectionID)
                            },
                            onSelect: { onSelect(item.id) },
                            onActivate: { onActivate(item.id) },
                            onCopy: { onCopy(item.id) },
                            onToggleFavorite: { onToggleFavorite(item.id) },
                            onToggleCollectionMembership: { collectionID in
                                onToggleCollectionMembership(item.id, collectionID)
                            },
                            onExport: { onExport(item.id) },
                            onShare: { onShare(item.id) },
                            onDelete: { onDelete(item.id) }
                        )
                        .id(item.id)
                    }
                }
                .padding(.vertical, HubTheme.Space.x1)
                .padding(.horizontal, HubTheme.Space.x1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .onChange(of: selectedItem?.id) { _, newValue in
                scrollToSelection(listProxy, newValue, false)
            }
            .onChange(of: hubOpenSequence) { _, _ in
                scrollToSelection(listProxy, selectedItem?.id, true)
            }
            .onAppear {
                scrollToSelection(listProxy, selectedItem?.id, true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - HubListRowView

struct HubListRowView: View {
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
