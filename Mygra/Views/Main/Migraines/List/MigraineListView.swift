//
//  MigraineListView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData

struct MigraineListView: View {
    @Environment(MigraineManager.self) private var migraineManager: MigraineManager
    @Binding var showingEntrySheet: Bool

    @Bindable var viewModel: MigraineListView.ViewModel = MigraineListView.ViewModel()

    var body: some View {
        Group {
            if migraineManager.visibleMigraines.isEmpty {
                let f = migraineManager.filter
                let defaultFilter = MigraineFilter()
                let hasNonPinnedFilters =
                    f.dateRange != nil ||
                    f.minPainLevel != nil ||
                    !f.requiredTriggers.isEmpty ||
                    !f.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasAnyFilter = f.pinnedOnly || hasNonPinnedFilters || f != defaultFilter

                if hasAnyFilter {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        VStack(spacing: 8) {
                            if f.pinnedOnly && hasNonPinnedFilters {
                                Text("Pinned-only and other filters are applied. Try clearing them to see more migraines.")
                            } else if f.pinnedOnly {
                                Text("Showing pinned only. Turn it off to see all migraines.")
                            } else {
                                Text("Filters are applied. Try clearing them to see more migraines.")
                            }
                            if !f.requiredTriggers.isEmpty {
                                Text(viewModel.triggerSummary(for: f.requiredTriggers))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            HStack(spacing: 12) {
                                if f.pinnedOnly {
                                    Button {
                                        Haptics.lightImpact()
                                        var new = f
                                        new.pinnedOnly = false
                                        migraineManager.filter = new
                                    } label: {
                                        Label("Show All", systemImage: "pin.slash")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.yellow)
                                    .accessibilityIdentifier("emptyShowAllButton")
                                }
                                Button {
                                    Haptics.success()
                                    migraineManager.filter = .init()
                                } label: {
                                    Label("Clear Filters", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                                .tint(.blue)
                                .accessibilityIdentifier("emptyClearFiltersButton")
                            }
                            .padding(.top, 4)
                        }
                    } actions: {
                        Button {
                            Haptics.lightImpact()
                            viewModel.showingFilterSheet = true
                        } label: {
                            Label("Adjust Filters", systemImage: "slider.horizontal.3")
                        }
                    }
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
                // Compute filter state for non-empty case
                let f = migraineManager.filter
                let defaultFilter = MigraineFilter()
                let hasNonPinnedFilters =
                    f.dateRange != nil ||
                    f.minPainLevel != nil ||
                    !f.requiredTriggers.isEmpty ||
                    !f.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let hasAnyFilter = f.pinnedOnly || hasNonPinnedFilters || f != defaultFilter

                List {
                    ForEach(migraineManager.visibleMigraines) { migraine in
                        NavigationLink {
                            MigraineDetailView(
                                migraine: migraine
                            )
                        } label: {
                            MigraineRowView(
                                migraine: migraine,
                                viewModel: viewModel
                            )
                        }
                        // Leading swipe: pin/unpin
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Haptics.lightImpact()
                                migraineManager.togglePinned(migraine)
                            } label: {
                                Label(migraine.pinned ? "Unpin" : "Pin",
                                      systemImage: migraine.pinned ? "pin.slash" : "pin")
                            }
                            .tint(.yellow)
                        }
                        // Trailing swipe: delete
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Haptics.error()
                                migraineManager.delete(migraine)
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .tint(.red)
                            }
                        }
                    }

                    // Footer alert when filters are active and there are results
                    if hasAnyFilter {
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
                                    if f.pinnedOnly {
                                        Button {
                                            Haptics.lightImpact()
                                            var new = f
                                            new.pinnedOnly = false
                                            migraineManager.filter = new
                                        } label: {
                                            Label("Show All", systemImage: "pin.slash")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.yellow)
                                        .controlSize(.small)
                                        .accessibilityIdentifier("footerShowAllButton")
                                    }
                                    if !f.requiredTriggers.isEmpty {
                                        Text(viewModel.triggerSummary(for: f.requiredTriggers))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .accessibilityIdentifier("footerTriggerSummary")
                                    }
                                    Button {
                                        Haptics.success()
                                        migraineManager.filter = .init()
                                    } label: {
                                        Label("Clear Filters", systemImage: "xmark.circle")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    .controlSize(.small)
                                    .accessibilityIdentifier("footerClearFiltersButton")
                                    
                                    Button {
                                        Haptics.lightImpact()
                                        viewModel.showingFilterSheet = true
                                    } label: {
                                        Label("Adjust", systemImage: "slider.horizontal.3")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .accessibilityIdentifier("footerAdjustFiltersButton")
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptics.lightImpact()
                    viewModel.showingFilterSheet = true
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
                .accessibilityIdentifier("filterButton")
                .tint(.green)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptics.lightImpact()
                    var f = migraineManager.filter
                    f.pinnedOnly.toggle()
                    migraineManager.filter = f
                } label: {
                    Label(
                        migraineManager.filter.pinnedOnly ? "Show All" : "Show Pinned",
                        systemImage: migraineManager.filter.pinnedOnly ? "pin.slash" : "pin"
                    )
                }
                .accessibilityIdentifier("pinnedOnlyToggle")
                .tint(.yellow)
            }
        }
        .sheet(isPresented: $viewModel.showingFilterSheet) {
            NavigationStack {
                MigraineFilterSheet(
                    initialFilter: migraineManager.filter,
                    apply: { newFilter in
                        migraineManager.filter = newFilter
                        viewModel.showingFilterSheet = false
                    },
                    reset: {
                        migraineManager.filter = .init()
                        viewModel.showingFilterSheet = false
                    },
                    cancel: {
                        viewModel.showingFilterSheet = false
                    }
                )
            }
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        }
        .refreshable {
            await migraineManager.refresh()
            Haptics.success()
        }
    }
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(
            for: User.self, Migraine.self, WeatherData.self, HealthData.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }
    let previewMigraineManager = MigraineManager(context: container.mainContext)
        
    return MigraineListView(showingEntrySheet: .constant(false))
        .modelContainer(container)
        .environment(previewMigraineManager)
}
