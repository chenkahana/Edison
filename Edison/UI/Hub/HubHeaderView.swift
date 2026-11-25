import SwiftUI

/// Top-of-hub controls: search pill, filter/type/layout pickers,
/// collection menu, and new-collection composer.
struct HubHeaderView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var filter: HubFilter
    @Binding var layoutMode: HubLayoutMode
    @Binding var newCollectionName: String
    @FocusState.Binding var focusedField: HubFocusTarget?
    /// The count after both the search/type/app/collection filters and the Hub's own All/Favorites
    /// toggle — shown next to the search field so a query's result count doesn't need counting cards.
    let resultCount: Int
    @State private var collectionPendingDeletion: ItemCollection?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: HubTheme.Space.x3) {
                searchPill
                    .frame(minWidth: 240, idealWidth: 320, maxWidth: 360)
                    .layoutPriority(1)

                pausedPill

                Spacer(minLength: 0)

                trailingControls
            }

            VStack(alignment: .leading, spacing: HubTheme.Space.x2) {
                HStack(alignment: .center, spacing: HubTheme.Space.x3) {
                    searchPill
                    pausedPill
                    Spacer(minLength: 0)
                    filterControls
                }

                collectionControls
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert(
            "Delete “\(collectionPendingDeletion?.name ?? "")”?",
            isPresented: Binding(
                get: { collectionPendingDeletion != nil },
                set: { if !$0 { collectionPendingDeletion = nil } }
            ),
            presenting: collectionPendingDeletion
        ) { collection in
            Button("Delete Collection", role: .destructive) {
                appState.deleteCollection(id: collection.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its items stay in your history. You can't undo this.")
        }
    }

    private var filterControls: some View {
        HStack(alignment: .center, spacing: HubTheme.Space.x2) {
            filterPicker
                .frame(width: 112)
            typePicker
                .frame(width: 288)
            layoutPicker
                .frame(width: 150)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var collectionControls: some View {
        HStack(alignment: .center, spacing: HubTheme.Space.x2) {
            topicMenu
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
                .font(HubTheme.TypeRamp.size14Medium)
                .foregroundStyle(HubTheme.textSecondary)
            TextField("Search words or meaning — try app:Safari", text: $appState.activeQuery)
                .textFieldStyle(.plain)
                .font(HubTheme.TypeRamp.size13Regular)
                .focused($focusedField, equals: .search)
            if !appState.activeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(resultCount == 1 ? "1 result" : "\(resultCount) results")
                    .font(HubTheme.TypeRamp.size12Medium)
                    .foregroundStyle(HubTheme.textSecondary)
                    .fixedSize()
            }
        }
        .padding(.horizontal, HubTheme.Space.x4)
        .frame(height: HubTheme.searchPillHeight)
        .background(
            Capsule(style: .continuous)
                .fill(HubTheme.cardFillMuted)
        )
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var pausedPill: some View {
        if appState.isHistoryPaused {
            Button {
                appState.setHistoryPaused(false)
            } label: {
                Label("History paused — Resume", systemImage: "pause.circle.fill")
                    .font(HubTheme.TypeRamp.size12Semibold)
                    .foregroundStyle(HubTheme.accentBrand)
                    .padding(.horizontal, HubTheme.Space.x3)
                    .frame(height: HubTheme.searchPillHeight)
                    .background(Capsule(style: .continuous).fill(HubTheme.accentBrand.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Edison is not recording new clipboard items")
        }
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
                Image(systemName: option.symbolName)
                    .help(option.rawValue)
                    .accessibilityLabel(option.rawValue)
                    .tag(option)
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

    /// The most common topic tags; choosing one adds its `topic:` token to the search, where it
    /// shows and can be removed like any other token.
    @ViewBuilder
    private var topicMenu: some View {
        let topics = HubTopicSummary.topTopics(in: appState.historyItems)
        if !topics.isEmpty {
            Menu {
                ForEach(topics, id: \.topic) { entry in
                    Button("\(entry.topic) (\(entry.count))") {
                        appState.addSearchToken(HistorySearchQuery.token(forTopic: entry.topic))
                    }
                }
            } label: {
                Label("Topics", systemImage: "tag")
                    .font(HubTheme.TypeRamp.size12Semibold)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.horizontal, HubTheme.Space.x3)
            .frame(height: HubTheme.searchPillHeight)
            .background(
                Capsule(style: .continuous)
                    .fill(HubTheme.cardFillMuted)
            )
            .help("Show items with a topic")
        }
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
                    collectionPendingDeletion = selected
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete Collection…")
                .accessibilityLabel("Delete Collection")
            }
        }
        .padding(.horizontal, HubTheme.Space.x3)
        .frame(height: HubTheme.searchPillHeight)
        .background(
            Capsule(style: .continuous)
                .fill(HubTheme.cardFillMuted)
        )
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
}

enum HubTopicSummary {
    /// Topics by how many items carry them, most first, then alphabetically.
    static func topTopics(in items: [ClipboardItem], limit: Int = 12) -> [(topic: String, count: Int)] {
        var counts: [String: Int] = [:]
        for item in items {
            for topic in item.topics { counts[topic, default: 0] += 1 }
        }
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(limit)
            .map { (topic: $0.key, count: $0.value) }
    }
}
