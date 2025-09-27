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
    var onSave: (_ startDate: Date, _ endDate: Date?, _ painLevel: Int, _ stressLevel: Int, _ triggers: Set<MigraineTrigger>, _ addedWater: Double, _ addedCaffeine: Double, _ addedFoodKcal: Double, _ addedSleepHours: Double) -> Void
    
    @State private var editStartDate: Date
    @State private var editEndDate: Date
    @State private var editIsOngoing: Bool
    @State private var editPainLevel: Int
    @State private var editStressLevel: Int
    @State private var selectedEditTriggers: Set<MigraineTrigger>
    @State private var modifyError: String?

    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    // Staged intake additions (do NOT write to HealthKit until Save)
    @State private var addWater: Double = 0
    @State private var addCaffeine: Double = 0
    @State private var addFoodKcal: Double = 0   // stored as kcal always
    @State private var addSleepHours: Double = 0

    // Editor UI state
    @State private var isEditingIntake: Bool = false
    @State private var intakeErrorMessage: String?
    
    init(migraine: Migraine, onCancel: @escaping () -> Void, onSave: @escaping (_ startDate: Date, _ endDate: Date?, _ painLevel: Int, _ stressLevel: Int, _ triggers: Set<MigraineTrigger>, _ addedWater: Double, _ addedCaffeine: Double, _ addedFoodKcal: Double, _ addedSleepHours: Double) -> Void) {
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
                        in: Date.distantPast...Date(),
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

                Section("Intake") {
                    // Display two-column summary mirroring the Entry screen, but sourced from the Migraine's saved snapshot.
                    let h = migraine.health
                    VStack {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let baseWater = h?.waterLiters {
                                    let addedLiters = useMetricUnits ? (addWater / 1000.0) : (addWater / 33.814)
                                    let litersTotal = baseWater + addedLiters
                                    let text = useMetricUnits
                                        ? String(format: "%.1f L", litersTotal)
                                        : String("\(Int((litersTotal * 33.814).rounded())) fl oz")
                                    Label(text, systemImage: "drop.fill")
                                        .foregroundStyle((addWater > 0) ? .yellow : .secondary)
                                }
                                if let baseSleep = h?.sleepHours {
                                    let total = baseSleep + addSleepHours
                                    Label("\(String(format: "%.1f", total)) h sleep", systemImage: "bed.double.fill")
                                        .foregroundStyle((addSleepHours > 0) ? .yellow : .secondary)
                                }
                                if let rhr = h?.restingHeartRate {
                                    Label("\(rhr) bpm RHR", systemImage: "heart.fill")
                                        .foregroundStyle(.secondary)
                                }
                                if let spo2 = h?.bloodOxygenPercent {
                                    let percent = spo2 * 100.0
                                    let s = percent.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(percent))% SpO₂" : String(format: "%.1f%% SpO₂", percent)
                                    Label(s, systemImage: "lungs.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: 8) {
                                if let baseKcal = h?.energyKilocalories {
                                    let totalKcal = baseKcal + addFoodKcal
                                    let text: String = {
                                        if useMetricUnits {
                                            let kJ = (totalKcal * 4.184).rounded()
                                            return "\(Int(kJ)) kJ"
                                        } else {
                                            return "\(Int(totalKcal)) kcal"
                                        }
                                    }()
                                    Label(text, systemImage: "fork.knife")
                                        .foregroundStyle((addFoodKcal > 0) ? .yellow : .secondary)
                                }
                                if let baseCaf = h?.caffeineMg {
                                    let totalMgRounded = (baseCaf + addCaffeine).rounded()
                                    Label("\(Int(totalMgRounded)) mg caffeine", systemImage: "cup.and.saucer.fill")
                                        .foregroundStyle((addCaffeine > 0) ? .yellow : .secondary)
                                }
                                if let steps = h?.stepCount {
                                    Label("\(steps) steps", systemImage: "figure.walk")
                                        .foregroundStyle(.secondary)
                                }
                                if let glucose = h?.glucoseMgPerdL {
                                    Label("\(Int(glucose)) mg/dL", systemImage: "syringe")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        // Intake editor toggle + editor
                        if !isEditingIntake {
                            HStack {
                                Spacer()
                                Button("Edit Intake Values") {
                                    Haptics.lightImpact()
                                    withAnimation { isEditingIntake = true }
                                }
                                .tint(.blue)
                                Spacer()
                            }
                            .padding([.top, .horizontal])
                        }

                        if isEditingIntake {
                            IntakeEditorView(
                                addWater: $addWater,
                                addCaffeine: $addCaffeine,
                                addFood: $addFoodKcal,
                                addSleepHours: $addSleepHours,
                                useMetricUnits: useMetricUnits,
                                waterRange: waterRange(useMetricUnits: useMetricUnits),
                                waterStep: waterStep(useMetricUnits: useMetricUnits),
                                waterDisplay: { waterDisplay($0, useMetricUnits: useMetricUnits) },
                                isSaving: false,
                                errorMessage: intakeErrorMessage,
                                allAddsAreZero: allAddsAreZero,
                                onAdd: {
                                    // Stage values only; do not write to HealthKit here.
                                    Haptics.success()
                                    withAnimation { isEditingIntake = false }
                                },
                                onCancel: {
                                    Haptics.lightImpact()
                                    addWater = 0
                                    addCaffeine = 0
                                    addFoodKcal = 0
                                    addSleepHours = 0
                                    intakeErrorMessage = nil
                                    withAnimation { isEditingIntake = false }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .scale,
                                removal: .scale
                            ))
                            .animation(.snappy(duration: 0.25), value: isEditingIntake)
                        }
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
    
    private var allAddsAreZero: Bool {
        addWater == 0 && addCaffeine == 0 && addFoodKcal == 0 && addSleepHours == 0
    }

    private func waterRange(useMetricUnits: Bool) -> ClosedRange<Double> {
        useMetricUnits ? (0...3000) : (0...128)
    }

    private func waterStep(useMetricUnits: Bool) -> Double {
        useMetricUnits ? 50 : 1
    }

    private func waterDisplay(_ value: Double, useMetricUnits: Bool) -> String {
        if useMetricUnits {
            return String(format: "+%.1f L", value / 1000.0)
        } else {
            return "+\(Int(value)) oz"
        }
    }

    private func validateAndSave() {
        modifyError = nil
        let now = Date()
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
        onSave(editStartDate, editIsOngoing ? nil : editEndDate, editPainLevel, editStressLevel, selectedEditTriggers, addWater, addCaffeine, addFoodKcal, addSleepHours)
    }
}

//#Preview {
//    ModifyMigraineSheetView(migraine: Migraine(startDate: Date.now, painLevel: 5, stressLevel: 5), onCancel: {}, onSave: { startDate, endDate, painLevel, stressLevel, triggers in
//        print("Preview Save -> start: \(startDate), end: \(String(describing: endDate)), pain: \(painLevel), stress: \(stressLevel), triggers: \(triggers))")
//    })
//}
