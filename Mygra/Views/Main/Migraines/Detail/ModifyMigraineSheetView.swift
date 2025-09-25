//
//  ModifyMigraineSheetView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import SwiftUI

struct ModifyMigraineSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    let migraine: Migraine
    var onCancel: () -> Void
    var onSave: (_ startDate: Date, _ endDate: Date?, _ painLevel: Int, _ stressLevel: Int, _ triggers: Set<MigraineTrigger>) -> Void
    
    @State private var editStartDate: Date
    @State private var editEndDate: Date
    @State private var editIsOngoing: Bool
    @State private var editPainLevel: Int
    @State private var editStressLevel: Int
    @State private var selectedEditTriggers: Set<MigraineTrigger>
    @State private var modifyError: String?
    
    init(migraine: Migraine, onCancel: @escaping () -> Void, onSave: @escaping (_ startDate: Date, _ endDate: Date?, _ painLevel: Int, _ stressLevel: Int, _ triggers: Set<MigraineTrigger>) -> Void) {
        self.migraine = migraine
        self.onCancel = onCancel
        self.onSave = onSave
        _editStartDate = State(initialValue: migraine.startDate)
        _editEndDate = State(initialValue: migraine.endDate ?? Date())
        _editIsOngoing = State(initialValue: migraine.endDate == nil)
        _editPainLevel = State(initialValue: migraine.painLevel)
        _editStressLevel = State(initialValue: migraine.stressLevel)
        _selectedEditTriggers = State(initialValue: Set(migraine.triggers))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    DatePicker(
                        "Start",
                        selection: $editStartDate,
                        in: (Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Toggle("Ongoing", isOn: $editIsOngoing)
                    if !editIsOngoing {
                        DatePicker(
                            "End",
                            selection: $editEndDate,
                            in: editStartDate...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                    if let err = modifyError {
                        Text(err).font(.footnote).foregroundStyle(.red)
                    }
                }
                
                Section("Experience") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Pain Level")
                            Spacer()
                            Text("\(editPainLevel)")
                                .bold()
                                .foregroundStyle(Severity.from(painLevel: editPainLevel).color)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(editPainLevel) },
                                set: { editPainLevel = Int(round($0)) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .tint(Severity.from(painLevel: editPainLevel).color)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stress Level")
                            Spacer()
                            Text("\(editStressLevel)")
                                .bold()
                                .foregroundStyle(.indigo)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(editStressLevel) },
                                set: { editStressLevel = Int(round($0)) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .tint(.indigo)
                    }
                }
                
                Section("Triggers") {
                    ForEach(MigraineTrigger.Group.allCases, id: \.self) { group in
                        let items = MigraineTrigger.allCases.filter { $0.group == group }
                        if !items.isEmpty {
                            DisclosureGroup(group.displayName) {
                                ForEach(items, id: \.self) { trig in
                                    Button {
                                        if selectedEditTriggers.contains(trig) {
                                            selectedEditTriggers.remove(trig)
                                        } else {
                                            selectedEditTriggers.insert(trig)
                                        }
                                        Haptics.lightImpact()
                                    } label: {
                                        HStack {
                                            Text(trig.displayName)
                                            Spacer()
                                            if selectedEditTriggers.contains(trig) {
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
                    if selectedEditTriggers.isEmpty {
                        Text("No triggers selected").foregroundStyle(.secondary)
                    } else {
                        Text("\(selectedEditTriggers.count) selected")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Modify Migraine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.lightImpact()
                        onCancel()
                    }
                    .tint(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.lightImpact()
                        validateAndSave()
                    }
                    .tint(.blue)
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
    
    private func validateAndSave() {
        modifyError = nil
        let earliest = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let now = Date()
        guard editStartDate >= earliest else {
            modifyError = "Start time cannot be more than 1 day in the past."
            Haptics.error()
            return
        }
        guard editStartDate <= now else {
            modifyError = "Start time cannot be in the future."
            Haptics.error()
            return
        }
        if !editIsOngoing {
            if editEndDate < editStartDate {
                modifyError = "End time must be after the start time."
                Haptics.error()
                return
            }
            if editEndDate > now {
                modifyError = "End time cannot be in the future."
                Haptics.error()
                return
            }
        }
        onSave(editStartDate, editIsOngoing ? nil : editEndDate, editPainLevel, editStressLevel, selectedEditTriggers)
    }
}

#Preview {
    ModifyMigraineSheetView(migraine: Migraine(startDate: Date.now, painLevel: 5, stressLevel: 5), onCancel: {}, onSave: { startDate, endDate, painLevel, stressLevel, triggers in
        print("Preview Save -> start: \(startDate), end: \(String(describing: endDate)), pain: \(painLevel), stress: \(stressLevel), triggers: \(triggers))")
    })
}
