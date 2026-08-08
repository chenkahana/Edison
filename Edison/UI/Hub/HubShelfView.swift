import AppKit
import SwiftUI

// MARK: - HubShelfView

/// The horizontal-scrolling shelf layout (rail mode).
struct HubShelfView: View {
    let items: [ClipboardItem]
    let selectedItem: ClipboardItem?
    let sideLength: CGFloat
    let hubOpenSequence: Int
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
    let scrollToSelection: (ScrollViewProxy, UUID?, Bool) -> Void

    var body: some View {
        ScrollViewReader { listProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: HubTheme.Space.x4) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                        HubShelfCardView(
                            item: item,
                            sideLength: sideLength,
                            collections: collections,
                            isSelected: item.id == selectedItem?.id,
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
                            onDelete: { onDelete(item.id) }
                        )
                        .id(item.id)
                    }
                }
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

// MARK: - HubShelfCardView

struct HubShelfCardView: View {
    let item: ClipboardItem
    let sideLength: CGFloat
    let collections: [ItemCollection]
    let isSelected: Bool
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
                onDelete: onDelete
            )
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

struct HubImagePreviewView: View {
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

struct HubCardFooter: View {
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
