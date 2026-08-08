import SwiftUI

/// Top-of-hub controls: search pill, filter/type/layout pickers,
/// collection menu, and new-collection composer.
struct HubHeaderView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var filter: HubFilter
    @Binding var layoutMode: HubLayoutMode
    @Binding var newCollectionName: String
    @FocusState.Binding var focusedField: HubFocusTarget?

    var body: some View {
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
