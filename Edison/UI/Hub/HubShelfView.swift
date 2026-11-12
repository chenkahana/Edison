import AppKit
import SwiftUI

// MARK: - HubShelfView

/// The horizontal-scrolling shelf layout (rail mode).
struct HubShelfView: View {
    let items: [ClipboardItem]
    let selectedItem: ClipboardItem?
    let sideLength: CGFloat
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
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: HubTheme.Space.x4) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HubShelfCardView(
                            item: item,
                            sideLength: sideLength,
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

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var kind: ClipboardContentKind { item.contentKind }
    private var accent: Color { HubTheme.accentColor(for: item) }
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: HubTheme.Radius.card, style: .continuous)
    }
    private var textLineLimit: Int {
        max(3, Int((sideLength - 84) / 20))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubCardHeader(item: item, kind: kind, accent: accent)
                .padding(.horizontal, HubTheme.Space.x3)
                .frame(height: 30)
                .background(accent.opacity(colorScheme == .dark ? 0.20 : 0.13))

            content
                .padding(.horizontal, HubTheme.Space.x3)
                .padding(.top, HubTheme.Space.x2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HubCardFooter(item: item)
                .padding(.horizontal, HubTheme.Space.x3)
                .padding(.bottom, HubTheme.Space.x2)
                .padding(.top, HubTheme.Space.x1)
        }
        .frame(width: sideLength, height: sideLength, alignment: .topLeading)
        .background(
            cardShape
                .fill(isSelected ? HubTheme.selectionFill : HubTheme.cardFill)
        )
        .overlay(
            cardShape
                .strokeBorder(
                    isSelected ? accent.opacity(0.85) : HubTheme.glassStroke.opacity(isHovered ? 0.9 : 0.55),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .clipShape(cardShape)
        .overlay(alignment: .bottomTrailing) {
            if let quickPasteNumber {
                HubQuickPasteBadge(number: quickPasteNumber)
                    .padding(HubTheme.Space.x2)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .shadow(color: HubTheme.cardShadowAmbient(colorScheme: colorScheme), radius: 10, y: 2)
        .shadow(color: HubTheme.cardShadowKey(colorScheme: colorScheme), radius: 28, x: 0, y: 10)
        .animation(HubTheme.Anim.fastSpring, value: quickPasteNumber)
        .contentShape(cardShape)
        .onHover { isHovered = $0 }
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
                onDelete: onDelete,
                onEditImage: onEditImage,
                onOpen: onOpen
            )
        }
        .accessibilityLabel("\(kind.title): \(item.accessibilityTitle)")
        .accessibilityValue(item.compactRelativeTimestamp)
    }

    @ViewBuilder
    private var content: some View {
        switch item.payload {
        case let .text(text):
            HubTextContentView(item: item, text: text, kind: kind, lineLimit: textLineLimit)
        case let .image(imageData):
            HubImagePreviewView(
                dataPath: imageData.thumbnailPath,
                fallbackSymbol: item.fallbackPreviewSymbol,
                accent: accent,
                cornerRadius: 10,
                padding: 0
            )
        case let .fileURL(url):
            HubFileContentView(url: url)
        }
    }
}

// MARK: - Card building blocks

struct HubCardHeader: View {
    let item: ClipboardItem
    let kind: ClipboardContentKind
    let accent: Color

    var body: some View {
        HStack(spacing: HubTheme.Space.x2) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent)
            Text(kind.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HubTheme.textPrimary)
                .lineLimit(1)
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HubTheme.accentBrand)
                    .accessibilityLabel("Favorite")
            }
            Spacer(minLength: 0)
            if let appIcon = item.sourceApplicationIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                    .help(item.sourceApplication?.localizedName ?? "")
            }
        }
    }
}

/// Text payloads rendered by what they are: links show their site, colours show a swatch,
/// code keeps its indentation. Rendering never changes the stored text.
struct HubTextContentView: View {
    let item: ClipboardItem
    let text: String
    let kind: ClipboardContentKind
    let lineLimit: Int

    var body: some View {
        switch kind {
        case .link:
            if let url = item.linkURL {
                linkContent(url)
            } else {
                plain
            }
        case .color:
            if let value = item.colorValue {
                colorContent(value)
            } else {
                plain
            }
        case .code:
            Text(HubCodePreview.displayText(text))
                .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                .foregroundStyle(HubTheme.textPrimary)
                .lineLimit(lineLimit + 1)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        default:
            plain
        }
    }

    private var plain: some View {
        HubClipboardTextView(text: text, fontSize: 14, fontWeight: .medium, lineLimit: lineLimit)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func linkContent(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x1) {
            Text(HubLinkPreview.displayHost(for: url))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(HubTheme.textPrimary)
                .lineLimit(2)
            Text(HubLinkPreview.displayPath(for: url))
                .font(.system(size: 12))
                .foregroundStyle(HubTheme.textSecondary)
                .lineLimit(max(2, lineLimit - 2))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func colorContent(_ value: ClipboardColorValue) -> some View {
        let swatch = Color(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: value.alpha)
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(swatch)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(value.hexString)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() != value.hexString {
                        Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(value.isLight || value.alpha < 0.5 ? Color.black.opacity(0.8) : Color.white)
                .padding(HubTheme.Space.x2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HubFileContentView: View {
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
            Image(nsImage: HubFileIconProvider.icon(for: url))
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)
            Text(url.lastPathComponent)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HubTheme.textPrimary)
                .lineLimit(2)
            Text((url.deletingLastPathComponent().path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath)
                .font(.system(size: 11))
                .foregroundStyle(HubTheme.textSecondary)
                .lineLimit(2)
                .truncationMode(.head)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct HubQuickPasteBadge: View {
    let number: Int

    var body: some View {
        Text("⌘\(number)")
            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(Color.black.opacity(0.72)))
            .accessibilityLabel("Command \(number) to paste")
    }
}

enum HubLinkPreview {
    static func displayHost(for url: URL) -> String {
        if url.scheme?.lowercased() == "mailto" {
            return url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
        }
        let host = url.host ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    static func displayPath(for url: URL) -> String {
        let path = url.path(percentEncoded: false)
        let query = url.query(percentEncoded: false).map { "?\($0)" } ?? ""
        let combined = path + query
        return combined.isEmpty || combined == "/" ? url.absoluteString : combined
    }
}

enum HubCodePreview {
    /// Display-only: drops surrounding blank lines and expands tabs so indentation stays readable.
    static func displayText(_ text: String) -> String {
        text.trimmingCharacters(in: .newlines).replacingOccurrences(of: "\t", with: "    ")
    }
}

enum HubFileIconProvider {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for url: URL) -> NSImage {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

/// Thumbnails are small and requested on every render, so decode each one once.
enum HubThumbnailCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 400
        return cache
    }()

    static func image(for relativePath: String) -> NSImage? {
        let url = ImageStore.imagesDirectoryURL.appendingPathComponent(relativePath)
        // Re-annotated screenshots keep their filename, so the modification date is part of the key.
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let key = "\(relativePath)|\(modified?.timeIntervalSinceReferenceDate ?? 0)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = try? ImageStore.load(relativePath: relativePath),
              let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
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

            if let image = HubThumbnailCache.image(for: dataPath) {
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
            Text(item.compactRelativeTimestamp)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HubTheme.textSecondary)
                .lineLimit(1)
            if let detail = item.detailSummary {
                Text("·")
                    .foregroundStyle(HubTheme.textTertiary)
                Text(detail)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(HubTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

extension ClipboardItem {
    /// Short, scannable metadata: character/line counts, image size, or file type.
    var detailSummary: String? {
        switch payload {
        case let .text(text):
            switch contentKind {
            case .link, .color:
                return nil
            default:
                let characters = text.count
                let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
                let charLabel = characters == 1 ? "1 char" : "\(characters.formatted()) chars"
                return lines > 1 ? "\(lines) lines" : charLabel
            }
        case let .image(image):
            guard let size = ImageStore.pixelSize(relativePath: image.imagePath) else { return nil }
            return "\(Int(size.width))×\(Int(size.height))"
        case let .fileURL(url):
            if url.hasDirectoryPath { return "Folder" }
            let ext = url.pathExtension.uppercased()
            return ext.isEmpty ? nil : ext
        }
    }
}
