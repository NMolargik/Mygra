//
//  MigrainesView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import SwiftUI
import SwiftData

struct MigrainesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Migraine.timestamp, order: .reverse)]) private var migraines: [Migraine]
    @Bindable var viewModel: MigrainesViewModel
    @Binding var selectedMigraine: Migraine?
    
    @State private var showFilterSheet = false
    @State private var showEntrySheet = false
    @State private var showPinnedOnly = false
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredMigraines(migraines, showPinnedOnly: showPinnedOnly), id: \.id) { migraine in
                    NavigationLink(value: migraine) {
                        MigraineRowView(migraine: migraine)
                    }
                    .swipeActions(edge: .leading) {
                        Button(action: {
                            togglePin(for: migraine)
                        }) {
                            Label(migraine.isPinned ? "Unpin" : "Pin", systemImage: migraine.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(.yellow)
                    }
                }
                .onDelete { offsets in
                    viewModel.deleteMigraines(at: offsets, filtered: viewModel.filteredMigraines(migraines, showPinnedOnly: showPinnedOnly))
                }
            }
            .navigationDestination(for: Migraine.self) { migraine in
                MigraineDetailView(migraine: migraine)
            }
            .environment(\.editMode, Binding(get: { editMode }, set: { editMode = $0 }))
            .navigationTitle("Migraines")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        toggleEditMode()
                    }) {
                        Text(editMode.isEditing ? "Done" : "Edit")
                            .bold()
                    }
                }
                
                if !editMode.isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showPinnedOnly.toggle() }) {
                            Image(systemName: showPinnedOnly ? "pin.fill" : "pin")
                                .foregroundStyle(showPinnedOnly ? .yellow : .primary)
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showFilterSheet = true }) {
                            Image(systemName: viewModel.isFiltered ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .foregroundStyle(viewModel.isFiltered ? .green : .primary)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showEntrySheet = true }) {
                            Text("New Migraine")
                                .bold()
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            // Sheet for filter settings, using binding to viewModel's showFilterSheet property
            .sheet(isPresented: $showFilterSheet) {
                MigraineFilterSheetView(filterSeverity: $viewModel.filterSeverity, filterDateRange: $viewModel.filterDateRange)
            }
            // Sheet for new migraine entry, using binding to viewModel's showEntrySheet property
            .sheet(isPresented: $showEntrySheet) {
                Text("Entry") // Replace with actual entry form view
            }
            .task {
                if migraines.isEmpty {
                    let samples: [Migraine] = [
                        Migraine(
                            timestamp: .now.addingTimeInterval(-3600 * 2),
                            severity: .severe,
                            notes: "Severe pain, missed work",
                            symptoms: ["nausea", "visual aura"].map { Symptom(name: $0) },
                            treatmentsTaken: ["sumatriptan"].map { Treatment(name: $0) }
                        ),
                        Migraine(
                            timestamp: .now.addingTimeInterval(-3600 * 24),
                            severity: .moderate,
                            notes: "Weather changed",
                            symptoms: ["light sensitivity"].map { Symptom(name: $0) },
                            treatmentsTaken: ["rest", "hydration"].map { Treatment(name: $0) }
                        ),
                        Migraine(
                            timestamp: .now.addingTimeInterval(-3600 * 48),
                            severity: .mild,
                            notes: "Stressful day",
                            symptoms: ["neck pain"].map { Symptom(name: $0) },
                            treatmentsTaken: ["ibuprofen"].map { Treatment(name: $0) }
                        )
                    ]
                    for migraine in samples {
                        modelContext.insert(migraine)
                    }
                }
            }
        }
    }
    
    func toggleEditMode() {
        editMode = editMode.isEditing ? .inactive : .active
    }
    
    func togglePin(for migraine: Migraine) {
        migraine.isPinned.toggle()
        try? viewModel.modelContext?.save()
    }
}

#Preview {
    MigrainesView(viewModel: MigrainesViewModel(), selectedMigraine: .constant(Migraine()))
        .modelContainer(for: [User.self, Migraine.self], inMemory: true)
}
