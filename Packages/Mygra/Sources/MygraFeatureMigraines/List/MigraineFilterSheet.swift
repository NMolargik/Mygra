//
//  MigraineFilterSheet.swift
//  MygraFeatureMigraines
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

struct MigraineFilterSheet: View {
    @State private var workingFilter: MigraineFilter
    @State private var useDateRange: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var triggerSearchText = ""

    let apply: (MigraineFilter) -> Void
    let cancel: () -> Void

    init(initialFilter: MigraineFilter, apply: @escaping (MigraineFilter) -> Void, cancel: @escaping () -> Void) {
        _workingFilter = State(initialValue: initialFilter)
        if let range = initialFilter.dateRange {
            _useDateRange = State(initialValue: true)
            _startDate = State(initialValue: range.lowerBound)
            _endDate = State(initialValue: range.upperBound)
        } else {
            let now = Date()
            _useDateRange = State(initialValue: false)
            _startDate = State(initialValue: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now)
            _endDate = State(initialValue: now)
        }
        self.apply = apply
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
                        .tint(.mygraPurple)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                        .tint(.mygraPurple)
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

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    SearchField("Search triggers", text: $triggerSearchText)
                        .padding(.vertical, 2)
                    Button {
                        Haptics.lightImpact()
                        workingFilter.requiredTriggers.removeAll()
                    } label: {
                        Label("Clear", systemImage: "circle.slash")
                    }
                    .glassActionButton(prominent: false)
                    .controlSize(.small)
                }

                TriggerPickerSection(selection: $workingFilter.requiredTriggers, searchText: triggerSearchText)
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
                Button("Cancel", role: .destructive) {
                    Haptics.lightImpact()
                    cancel()
                }
                .foregroundStyle(.red)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    var filter = workingFilter
                    filter.dateRange = useDateRange ? min(startDate, endDate)...max(startDate, endDate) : nil
                    Haptics.success()
                    apply(filter)
                }
                .foregroundStyle(.mygraBlue)
            }
        }
    }
}

#if DEBUG
#Preview("Default") {
    NavigationStack {
        MigraineFilterSheet(initialFilter: MigraineFilter(minPainLevel: 3), apply: { _ in }, cancel: {})
    }
}
#endif
#endif
