//
//  MigraineListView.swift
//  MygraFeatureMigraines
//
//  The filterable migraine list with pin/delete swipes and the filter sheet.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

public struct MigraineListView: View {
    @Environment(MigraineDataModel.self) private var migraineData

    @State private var showingFilterSheet = false

    public init() {}

    private var filter: MigraineFilter { migraineData.filter }

    public var body: some View {
        Group {
            if migraineData.visibleMigraines.isEmpty {
                if filter.isActive {
                    filteredEmptyState
                } else {
                    ScrollView {
                        ContentUnavailableView(
                            "No Migraines Yet",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Your logged migraines will appear here.")
                        )
                    }
                }
            } else {
                list
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptics.lightImpact()
                    showingFilterSheet = true
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
                .accessibilityIdentifier("filterButton")
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptics.lightImpact()
                    migraineData.filter.pinnedOnly.toggle()
                } label: {
                    Label(
                        filter.pinnedOnly ? "Show All" : "Show Pinned",
                        systemImage: filter.pinnedOnly ? "pin.fill" : "pin"
                    )
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
            .interactiveDismissDisabled()
        }
        .refreshable {
            migraineData.refresh()
            Haptics.success()
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(migraineData.visibleMigraines) { migraine in
                NavigationLink(value: migraine.id) {
                    MigraineRowView(migraine: migraine)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Haptics.lightImpact()
                        migraineData.togglePinned(migraine)
                    } label: {
                        Label(migraine.isPinned ? "Unpin" : "Pin", systemImage: migraine.isPinned ? "pin.slash" : "pin")
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Haptics.error()
                        migraineData.delete(migraine)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if filter.isActive {
                Section {
                    EmptyView()
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundStyle(.secondary)
                            Text("Filters are applied")
                                .font(.footnote).bold()
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            if filter.pinnedOnly {
                                showAllButton
                                    .controlSize(.small)
                                    .accessibilityIdentifier("footerShowAllButton")
                            }
                            if !filter.requiredTriggers.isEmpty {
                                Text(filter.requiredTriggerSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("footerTriggerSummary")
                            }
                            clearFiltersButton
                                .controlSize(.small)
                                .accessibilityIdentifier("footerClearFiltersButton")
                            adjustFiltersButton(title: "Adjust")
                                .controlSize(.small)
                                .accessibilityIdentifier("footerAdjustFiltersButton")
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Empty state

    private var filteredEmptyState: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            VStack(spacing: 8) {
                if filter.pinnedOnly && filter.hasCriteria {
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 12) {
                    if filter.pinnedOnly {
                        showAllButton
                            .accessibilityIdentifier("emptyShowAllButton")
                    }
                    clearFiltersButton
                        .accessibilityIdentifier("emptyClearFiltersButton")
                }
                .padding(.top, 4)
            }
        } actions: {
            adjustFiltersButton(title: "Adjust Filters")
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
