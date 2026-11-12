import AppKit
import SwiftUI

// MARK: - HubListView

/// The vertical-scrolling list layout mode.
struct HubListView: View {
    let items: [ClipboardItem]
    let selectedItem: ClipboardItem?
    let hubOpenSequence: Int
    let showsQuickPasteBadges: Bool
    let collections: [ItemCollection]
    let isInCollection: (UUID, UUID) -> Bool
    let onSelect: (UUID) -> Void
    let onActivate: (UUID) -> Void
    let onPasteAsPlainText: (UUID) -> Void
    let onCopy: (UUID) -> Void
    let onToggleFavorite: (UUID) -> Void
    let onToggleCollectionMembership: (UUID, UUID) -> Void
    let onExport: (UUID) -> Void
    let onShare: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onEditImage: (UUID) -> Void
    let onOpen: (UUID) -> Void
    let scrollToSelection: (ScrollViewProxy, UUID?, Bool) -> Void

    var body: some View {
        ScrollViewReader { listProxy in
            ScrollView {
                LazyVStack(spacing: HubTheme.Space.x2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HubListRowView(
                            item: item,
                            collections: collections,
                            isSelected: item.id == selectedItem?.id,
                            quickPasteNumber: showsQuickPasteBadges && index < 9 ? index + 1 : nil,
                            isInCollection: { collectionID in
                                isInCollection(item.id, collectionID)
                            },
                            onSelect: { onSelect(item.id) },
                            onActivate: { onActivate(item.id) },
                            onPasteAsPlainText: { onPasteAsPlainText(item.id) },
                            onCopy: { onCopy(item.id) },
                            onToggleFavorite: { onToggleFavorite(item.id) },
                            onToggleCollectionMembership: { collectionID in
                                onToggleCollectionMembership(item.id, collectionID)
                            },
                            onExport: { onExport(item.id) },
                            onShare: { onShare(item.id) },
                            onDelete: { onDelete(item.id) },
                            onEditImage: { onEditImage(item.id) },
                            onOpen: { onOpen(item.id) }
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
    var quickPasteNumber: Int?
    let isInCollection: (UUID) -> Bool
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onPasteAsPlainText: () -> Void
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleCollectionMembership: (UUID) -> Void
    let onExport: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    var onEditImage: (() -> Void)?
    var onOpen: (() -> Void)?

    private var accent: Color { HubTheme.accentColor(for: item) }
    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
    }

    var body: some View {
        HStack(alignment: .center, spacing: HubTheme.Space.x3) {
            if case .image = item.payload {
                preview
            } else {
                kindBadge
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

            if let appIcon = item.sourceApplicationIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 20, height: 20)
                    .help(item.sourceApplication?.localizedName ?? "")
            }
            if let quickPasteNumber {
                HubQuickPasteBadge(number: quickPasteNumber)
            }
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
            HubItemActionMenu(
                item: item,
                collections: collections,
                isInCollection: isInCollection,
                onPaste: onActivate,
                onPasteAsPlainText: onPasteAsPlainText,
                onCopy: onCopy,
                onToggleFavorite: onToggleFavorite,
                onToggleCollectionMembership: onToggleCollectionMembership,
                onExport: onExport,
                onShare: onShare,
                onDelete: onDelete,
                onEditImage: onEditImage,
                onOpen: onOpen
            )
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

    private var kindBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.16))
            Image(systemName: item.contentKind.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
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
