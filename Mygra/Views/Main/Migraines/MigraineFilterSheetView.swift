//
//  MigraineFilterSheetView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import SwiftUI

struct MigraineFilterSheetView: View {
    @Binding var filterSeverity: Migraine.Severity?
    @Binding var filterDateRange: ClosedRange<Date>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Filter by Severity")) {
                    Picker("Severity", selection: $filterSeverity) {
                        Text("All").tag(Migraine.Severity?.none)
                        ForEach(Migraine.Severity.allCases, id: \.self) { severity in
                            Text(severity.rawValue).tag(Migraine.Severity?.some(severity))
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("Filter by Date Range")) {
                    DatePicker("Start Date", selection: Binding(
                        get: { filterDateRange?.lowerBound ?? Date().addingTimeInterval(-7 * 24 * 3600) },
                        set: { newValue in
                            let end = filterDateRange?.upperBound ?? Date()
                            filterDateRange = newValue...end
                        }
                    ), displayedComponents: .date)
                    DatePicker("End Date", selection: Binding(
                        get: { filterDateRange?.upperBound ?? Date() },
                        set: { newValue in
                            let start = filterDateRange?.lowerBound ?? Date().addingTimeInterval(-7 * 24 * 3600)
                            filterDateRange = start...newValue
                        }
                    ), displayedComponents: .date)
                    Button("Clear Date Range") {
                        filterDateRange = nil
                    }
                    .disabled(filterDateRange == nil)
                }
            }
            .navigationTitle("Filter Migraines")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MigraineFilterSheetView(filterSeverity: .constant(.none), filterDateRange: .constant(nil))
}
