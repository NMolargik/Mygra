//
//  MigraineListView.swift
//  MygraFeatureMigraines
//
//  The searchable, filterable migraine history: pinned entries first, then one section
//  per month. Swipe to pin or delete, long-press for the same actions, and a filter
//  sheet for everything else.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

public struct MigraineListView: View {
    @Environment(MigraineDataModel.self) private var migraineData
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false

    @State private var showingFilterSheet = false
    @State private var searchText = ""

    public init() {}

    private var filter: MigraineFilter { migraineData.filter }

    /// The search field is kept out of the persisted filter so clearing it never
    /// disturbs the user's pin/trigger choices.
    private var searchFilter: MigraineFilter {
        var combined = filter
        combined.searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return combined
    }

    private var visible: [Migraine] {
        migraineData.migraines.filter { searchFilter.matches($0) }
    }

    private var pinned: [Migraine] { visible.filter(\.isPinned) }
    private var unpinned: [Migraine] { visible.filter { !$0.isPinned } }

    private var monthGroups: [MigraineMonthGroup] {
        MigraineStatistics.monthGroups(unpinned)
    }

    private var migrainesByID: [UUID: Migraine] {
        Dictionary(unpinned.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public var body: some View {
        Group {
            if visible.isEmpty {
                if searchFilter.isActive {
                    filteredEmptyState
                } else {
                    emptyState
                }
            } else {
                list
            }
        }
        .searchable(text: $searchText, prompt: Text("Search notes, triggers, and insights"))
        .minimizingSearchIfAvailable()
        .navigationSubtitleIfAvailable(subtitle)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    Haptics.lightImpact()
                    showingFilterSheet = true
                } label: {
                    Label("Filter", systemImage: filter.hasCriteria ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .symbolRenderingMode(filter.hasCriteria ? .multicolor : .monochrome)
                }
                .accessibilityIdentifier("filterButton")
                .accessibilityValue(filter.hasCriteria ? Text("Active") : Text("Off"))
            }
            ToolbarItem(placement: .secondaryAction) {
                Toggle(isOn: pinnedOnlyBinding) {
                    Label("Pinned Only", systemImage: filter.pinnedOnly ? "pin.fill" : "pin")
                }
                .accessibilityIdentifier("pinnedOnlyToggle")
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            NavigationStack {
                MigraineFilterSheet(
                    initialFilter: filter,
                    apply: { newFilter in
                        migraineData.filter = newFilter
                        showingFilterSheet = false
                    },
                    cancel: { showingFilterSheet = false }
                )
            }
            .presentationDetents([.large])
            .presentationSizing(.page)
            .interactiveDismissDisabled()
        }
        .refreshable {
            migraineData.refresh()
            Haptics.success()
        }
    }

    private var subtitle: String {
        let count = visible.count
        if searchFilter.isActive {
            return String(localized: "\(count) matching")
        }
        return count == 1 ? String(localized: "1 migraine") : String(localized: "\(count) migraines")
    }

    private var pinnedOnlyBinding: Binding<Bool> {
        Binding(
            get: { filter.pinnedOnly },
            set: { newValue in
                Haptics.lightImpact()
                migraineData.filter.pinnedOnly = newValue
            }
        )
    }

    // MARK: - List

    private var list: some View {
        List {
            if !pinned.isEmpty {
                Section {
                    ForEach(pinned) { migraine in
                        row(migraine)
                    }
                } header: {
                    Label("Pinned", systemImage: "pin.fill")
                        .foregroundStyle(.yellow)
                }
            }

            let lookup = migrainesByID
            ForEach(monthGroups) { group in
                Section {
                    ForEach(group.migraineIDs.compactMap { lookup[$0] }) { migraine in
                        row(migraine)
                    }
                } header: {
                    Text(group.monthStart, format: .dateTime.month(.wide).year())
                }
            }

            if filter.isActive {
                Section {
                    EmptyView()
                } footer: {
                    activeFilterFooter
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy, value: visible.map(\.id))
    }

    private func row(_ migraine: Migraine) -> some View {
        NavigationLink(value: migraine.id) {
            MigraineRowView(migraine: migraine)
        }
        .hoverHighlight()
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Haptics.lightImpact()
                migraineData.togglePinned(migraine)
            } label: {
                Label(migraine.isPinned ? "Unpin" : "Pin", systemImage: migraine.isPinned ? "pin.slash" : "pin")
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Haptics.error()
                migraineData.delete(migraine)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                Haptics.lightImpact()
                migraineData.togglePinned(migraine)
            } label: {
                Label(migraine.isPinned ? "Unpin" : "Pin", systemImage: migraine.isPinned ? "pin.slash" : "pin")
            }
            if migraine.isOngoing {
                Button {
                    Haptics.success()
                    migraineData.endOngoing()
                } label: {
                    Label("End Migraine", systemImage: "stop.circle")
                }
            }
            Divider()
            Button(role: .destructive) {
                Haptics.error()
                migraineData.delete(migraine)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } preview: {
            MigraineRowView(migraine: migraine)
                .padding()
                .frame(width: 340)
        }
    }

    private var activeFilterFooter: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            Label("Filters are applied", systemImage: "line.3.horizontal.decrease.circle")
                .font(.footnote.weight(.semibold))
            if !filter.requiredTriggers.isEmpty {
                Text(filter.requiredTriggerSummary)
                    .font(.caption)
                    .accessibilityIdentifier("footerTriggerSummary")
            }
            HStack(spacing: Brand.Space.sm) {
                if filter.pinnedOnly {
                    showAllButton
                        .controlSize(.small)
                        .accessibilityIdentifier("footerShowAllButton")
                }
                clearFiltersButton
                    .controlSize(.small)
                    .accessibilityIdentifier("footerClearFiltersButton")
                adjustFiltersButton(title: "Adjust")
                    .controlSize(.small)
                    .accessibilityIdentifier("footerAdjustFiltersButton")
            }
        }
        .padding(.top, Brand.Space.xs)
    }

    // MARK: - Empty states

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Migraines Yet", systemImage: "list.bullet.rectangle")
        } description: {
            Text("Your logged migraines will appear here. Tap New Migraine to add your first.")
        }
    }

    private var filteredEmptyState: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: searchText.isEmpty ? "line.3.horizontal.decrease.circle" : "magnifyingglass")
        } description: {
            VStack(spacing: Brand.Space.sm) {
                if !searchText.isEmpty {
                    Text("Nothing matches “\(searchText)”.")
                } else if filter.pinnedOnly && filter.hasCriteria {
                    Text("Pinned-only and other filters are applied. Try clearing them to see more migraines.")
                } else if filter.pinnedOnly {
                    Text("Showing pinned only. Turn it off to see all migraines.")
                } else {
                    Text("Filters are applied. Try clearing them to see more migraines.")
                }
                if !filter.requiredTriggers.isEmpty {
                    Text(filter.requiredTriggerSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } actions: {
            HStack(spacing: Brand.Space.md) {
                if filter.pinnedOnly {
                    showAllButton
                        .accessibilityIdentifier("emptyShowAllButton")
                }
                if filter.hasCriteria {
                    clearFiltersButton
                        .accessibilityIdentifier("emptyClearFiltersButton")
                }
                adjustFiltersButton(title: "Adjust Filters")
            }
        }
    }

    // MARK: - Buttons

    private var showAllButton: some View {
        Button {
            Haptics.lightImpact()
            migraineData.filter.pinnedOnly = false
        } label: {
            Label("Show All", systemImage: "pin.slash")
        }
        .glassActionButton(prominent: false)
    }

    private var clearFiltersButton: some View {
        Button {
            Haptics.success()
            migraineData.filter = MigraineFilter()
            searchText = ""
        } label: {
            Label("Clear Filters", systemImage: "xmark.circle")
        }
        .glassActionButton()
    }

    private func adjustFiltersButton(title: LocalizedStringKey) -> some View {
        Button {
            Haptics.lightImpact()
            showingFilterSheet = true
        } label: {
            Label(title, systemImage: "slider.horizontal.3")
        }
        .glassActionButton(prominent: false)
    }
}

#Preview {
    NavigationStack {
        MigraineListView()
            .navigationTitle("Migraines")
    }
    .previewEnvironment()
}
#endif
