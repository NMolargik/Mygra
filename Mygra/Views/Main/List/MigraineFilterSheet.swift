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

    // Triggers UI state
    @State private var triggerSearchText: String = ""
    
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
                Toggle("Filter by Date", isOn: Binding(
                    get: { useDateRange },
                    set: { newValue in
                        useDateRange = newValue
                        Haptics.lightImpact()
                    }
                ))
                .tint(.green)
                
                if useDateRange {
                    DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                }
            }
            
            Section("Pain Level") {
                Stepper(
                    value: Binding(
                        get: { workingFilter.minPainLevel ?? 0 },
                        set: { newValue in
                            workingFilter.minPainLevel = newValue == 0 ? nil : newValue
                            Haptics.lightImpact()
                        }
                    ),
                    in: 0...10
                ) {
                    Text("Minimum Pain: \(workingFilter.minPainLevel ?? 0)")
                }
                Text("Set to zero for no minimum").font(.footnote).foregroundStyle(.secondary)
            }
            
            Section("Search") {
                TextField("Search notes or insights", text: $workingFilter.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            // Triggers multi-select
            Section {
                // Search + quick actions row
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Search triggers", text: $triggerSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !triggerSearchText.isEmpty {
                            Button {
                                Haptics.lightImpact()
                                triggerSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear trigger search")
                        }
                    }
                    .padding(.vertical, 2)
                    
                    HStack(spacing: 8) {
                        Button {
                            Haptics.lightImpact()
                            workingFilter.requiredTriggers.removeAll()
                        } label: {
                            Label("Clear", systemImage: "circle.slash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                // Grouped lists by category, filtered by search
                ForEach(MigraineTrigger.Group.allCases, id: \.self) { group in
                    let items = filteredTriggers(for: group, search: triggerSearchText)
                    if !items.isEmpty {
                        DisclosureGroup(groupTitle(group)) {
                            ForEach(items, id: \.self) { trig in
                                Button {
                                    Haptics.lightImpact()
                                    toggleRequired(trig)
                                } label: {
                                    HStack {
                                        Text(trig.displayName)
                                        Spacer()
                                        if workingFilter.requiredTriggers.contains(trig) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.red)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } header: {
                HStack(spacing: 6) {
                    Text("Triggers")
                    if workingFilter.requiredTriggers.isEmpty {
                        Text("Optional").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } footer: {
                if workingFilter.requiredTriggers.isEmpty {
                    Text("Select one or more triggers to require them in results.")
                } else {
                    Text("\(workingFilter.requiredTriggers.count) selected")
                }
            }
        }
        .navigationTitle("Filter Migraines")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    Haptics.lightImpact()
                    cancel()
                }
                .foregroundStyle(.red)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    var f = workingFilter
                    f.dateRange = useDateRange ? min(startDate, endDate)...max(startDate, endDate) : nil
                    Haptics.success()
                    apply(f)
                }
                .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Triggers helpers
    private func groupTitle(_ group: MigraineTrigger.Group) -> String {
        group.rawValue.capitalized
    }
    
    private func filteredTriggers(for group: MigraineTrigger.Group, search: String) -> [MigraineTrigger] {
        let all = MigraineTrigger.cases(for: group)
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let lower = trimmed.lowercased()
        return all.filter { $0.displayName.lowercased().contains(lower) }
    }
    
    private func toggleRequired(_ trigger: MigraineTrigger) {
        if workingFilter.requiredTriggers.contains(trigger) {
            workingFilter.requiredTriggers.remove(trigger)
        } else {
            workingFilter.requiredTriggers.insert(trigger)
        }
    }
}

// MARK: - Previews
private extension MigraineFilter {
    static var previewValue: MigraineFilter {
        var f = MigraineFilter()
        // Example defaults for preview
        f.minPainLevel = 3
        f.searchText = ""
        // Leave dateRange and requiredTriggers empty by default
        return f
    }

    static var previewWithRange: MigraineFilter {
        var f = MigraineFilter.previewValue
        let now = Date()
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        f.dateRange = twoWeeksAgo...now
        return f
    }
}

#Preview("Default") {
    NavigationStack {
        MigraineFilterSheet(
            initialFilter: .previewValue,
            apply: { _ in },
            reset: {},
            cancel: {}
        )
    }
}

#Preview("With Date Range") {
    NavigationStack {
        MigraineFilterSheet(
            initialFilter: .previewWithRange,
            apply: { _ in },
            reset: {},
            cancel: {}
        )
    }
}
