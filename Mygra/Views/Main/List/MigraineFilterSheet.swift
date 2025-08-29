//
//  MigraineFilterSheet.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import SwiftUI

struct MigraineFilterSheet: View {
    @State private var workingFilter: MigraineFilter
    
    // Simple date range controls
    @State private var useDateRange: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    
    // Callbacks
    var apply: (MigraineFilter) -> Void
    var reset: () -> Void
    var cancel: () -> Void
    
    init(
        initialFilter: MigraineFilter,
        apply: @escaping (MigraineFilter) -> Void,
        reset: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) {
        self._workingFilter = State(initialValue: initialFilter)
        if let r = initialFilter.dateRange {
            self._useDateRange = State(initialValue: true)
            self._startDate = State(initialValue: r.lowerBound)
            self._endDate = State(initialValue: r.upperBound)
        } else {
            let now = Date()
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            self._useDateRange = State(initialValue: false)
            self._startDate = State(initialValue: oneWeekAgo)
            self._endDate = State(initialValue: now)
        }
        self.apply = apply
        self.reset = reset
        self.cancel = cancel
    }
    
    var body: some View {
        Form {
            Section("Date Range") {
                Toggle("Filter by Date", isOn: $useDateRange)
                if useDateRange {
                    DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                }
            }
            
            Section("Pain Level") {
                Stepper(value: Binding(
                    get: { workingFilter.minPainLevel ?? 0 },
                    set: { workingFilter.minPainLevel = $0 == 0 ? nil : $0 }
                ), in: 0...10) {
                    Text("Minimum Pain: \(workingFilter.minPainLevel ?? 0)")
                }
                Text("0 means no minimum").font(.footnote).foregroundStyle(.secondary)
            }
            
            Section("Search") {
                TextField("Search notes or insights", text: $workingFilter.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            // Placeholder for trigger filtering; wiring to real triggers can be added later
            Section("Triggers") {
                if workingFilter.requiredTriggers.isEmpty {
                    Text("No required triggers").foregroundStyle(.secondary)
                } else {
                    Text("\(workingFilter.requiredTriggers.count) selected")
                }
                Text("A trigger picker can be added here later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Filter Migraines")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { cancel() }
                    .foregroundStyle(.red)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    var f = workingFilter
                    f.dateRange = useDateRange ? min(startDate, endDate)...max(startDate, endDate) : nil
                    apply(f)
                }
                .foregroundStyle(.blue)
            }
        }
    }
}
