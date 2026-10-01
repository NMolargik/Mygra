//
//  IntakeSection.swift
//  MygraFeatureShared
//
//  A two-column summary of a Health snapshot with the staged additions folded in, plus
//  a collapsible intake editor. Shared by the entry form and the modify sheet.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

public struct IntakeSection: View {
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    let baseHealth: HealthData
    @Binding var isEditing: Bool
    @Binding var additions: IntakeAdditions
    let isSaving: Bool
    let errorMessage: String?
    let onConfirmAdd: () -> Void
    let onCancel: () -> Void

    public init(
        baseHealth: HealthData,
        isEditing: Binding<Bool>,
        additions: Binding<IntakeAdditions>,
        isSaving: Bool = false,
        errorMessage: String? = nil,
        onConfirmAdd: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.baseHealth = baseHealth
        _isEditing = isEditing
        _additions = additions
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onConfirmAdd = onConfirmAdd
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    if let water = baseHealth.waterLiters {
                        let total = water + additions.waterLiters
                        let text = useMetricUnits
                            ? String(format: "%.1f L", total)
                            : "\(Int((total * UnitConversion.litersToFluidOunces).rounded())) fl oz"
                        Label(text, systemImage: "drop.fill")
                            .foregroundStyle(additions.waterLiters > 0 ? .yellow : .secondary)
                    }
                    if let sleep = baseHealth.sleepHours {
                        Label("\(String(format: "%.1f", sleep + additions.sleepHours)) h sleep", systemImage: "bed.double.fill")
                            .foregroundStyle(additions.sleepHours > 0 ? .yellow : .secondary)
                    }
                    if let rhr = baseHealth.restingHeartRate {
                        Label("\(rhr) bpm RHR", systemImage: "heart.fill")
                            .foregroundStyle(.secondary)
                    }
                    if let spo2 = baseHealth.bloodOxygenPercent {
                        let percent = spo2 * 100.0
                        let text = percent.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(percent))% SpO₂" : String(format: "%.1f%% SpO₂", percent)
                        Label(text, systemImage: "lungs.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    if let kcal = baseHealth.energyKilocalories {
                        let total = kcal + additions.foodKilocalories
                        let text = useMetricUnits
                            ? "\(Int((total * UnitConversion.kilocaloriesToKilojoules).rounded())) kJ"
                            : "\(Int(total.rounded())) kcal"
                        Label(text, systemImage: "fork.knife")
                            .foregroundStyle(additions.foodKilocalories > 0 ? .yellow : .secondary)
                    }
                    if let caffeine = baseHealth.caffeineMg {
                        Label("\(Int((caffeine + additions.caffeineMg).rounded())) mg caffeine", systemImage: "cup.and.saucer.fill")
                            .foregroundStyle(additions.caffeineMg > 0 ? .yellow : .secondary)
                    }
                    if let steps = baseHealth.stepCount {
                        Label("\(steps) steps", systemImage: "figure.walk")
                            .foregroundStyle(.secondary)
                    }
                    if let glucose = baseHealth.glucoseMgPerdL {
                        Label("\(Int(glucose)) mg/dL", systemImage: "syringe")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if !isEditing {
                HStack {
                    Spacer()
                    Button("Add Consumption") {
                        Haptics.lightImpact()
                        withAnimation { isEditing = true }
                    }
                    .glassActionButton(prominent: false)
                    Spacer()
                }
                .padding([.top, .horizontal])
            }

            if isEditing {
                Divider()
                IntakeEditorView(
                    additions: $additions,
                    isSaving: isSaving,
                    errorMessage: errorMessage,
                    onAdd: onConfirmAdd,
                    onCancel: {
                        Haptics.lightImpact()
                        withAnimation { isEditing = false }
                        onCancel()
                    }
                )
                .transition(.asymmetric(insertion: .scale, removal: .scale))
                .animation(.snappy(duration: 0.25), value: isEditing)
            }
        }
    }
}

#Preview {
    struct PreviewView: View {
        @State var isEditing = false
        @State var additions = IntakeAdditions()
        var body: some View {
            Form {
                IntakeSection(
                    baseHealth: HealthData(waterLiters: 1.2, sleepHours: 6.5, energyKilocalories: 1800, caffeineMg: 120, stepCount: 5400, restingHeartRate: 58, bloodOxygenPercent: 0.97),
                    isEditing: $isEditing,
                    additions: $additions,
                    onConfirmAdd: {},
                    onCancel: {}
                )
            }
        }
    }
    return PreviewView()
}
#endif
