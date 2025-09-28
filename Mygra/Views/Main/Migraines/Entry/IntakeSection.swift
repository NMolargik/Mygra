//
//  IntakeSection.swift
//  Mygra
//
//  Created by Nick Molargik on 9/26/25.
//

import SwiftUI

struct IntakeSection: View {
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    let baseHealth: HealthData
    @Binding var isEditing: Bool
    @Binding var addWater: Double
    @Binding var addCaffeine: Double
    @Binding var addFoodKcal: Double
    @Binding var addSleepHours: Double
    let isSaving: Bool
    let errorMessage: String?
    let allAddsAreZero: Bool
    let onConfirmAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack {
            // Two-column summary mirroring both screens, but computed with staged adds
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    if let baseWater = baseHealth.waterLiters {
                        // addWater is stored in liters regardless of unit preference; only convert for display
                        let litersTotal = baseWater + addWater
                        let text = useMetricUnits
                            ? String(format: "%.1f L", litersTotal)
                            : String("\(Int((litersTotal * 33.814).rounded())) fl oz")
                        Label(text, systemImage: "drop.fill")
                            .foregroundStyle((addWater > 0) ? .yellow : .secondary)
                    }
                    if let baseSleep = baseHealth.sleepHours {
                        let total = baseSleep + addSleepHours
                        Label("\(String(format: "%.1f", total)) h sleep", systemImage: "bed.double.fill")
                            .foregroundStyle((addSleepHours > 0) ? .yellow : .secondary)
                    }
                    if let rhr = baseHealth.restingHeartRate {
                        Label("\(rhr) bpm RHR", systemImage: "heart.fill")
                            .foregroundStyle(.secondary)
                    }
                    if let spo2 = baseHealth.bloodOxygenPercent {
                        let percent = spo2 * 100.0
                        let s = percent.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(percent))% SpO₂" : String(format: "%.1f%% SpO₂", percent)
                        Label(s, systemImage: "lungs.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    if let baseKcal = baseHealth.energyKilocalories {
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
                    if let baseCaf = baseHealth.caffeineMg {
                        let totalMgRounded = (baseCaf + addCaffeine).rounded()
                        Label("\(Int(totalMgRounded)) mg caffeine", systemImage: "cup.and.saucer.fill")
                            .foregroundStyle((addCaffeine > 0) ? .yellow : .secondary)
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

            // Toggle + editor using a collapsible to avoid jumps
            if !isEditing {
                HStack {
                    Spacer()
                    Button("Edit Intake Values") {
                        Haptics.lightImpact()
                        withAnimation { isEditing = true }
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    Spacer()
                }
                .padding([.top, .horizontal])
            }

            if isEditing {
                Divider()
                
                IntakeEditorView(
                    addWater: $addWater,
                    addCaffeine: $addCaffeine,
                    addFood: $addFoodKcal,
                    addSleepHours: $addSleepHours,
                    isSaving: isSaving,
                    errorMessage: errorMessage,
                    allAddsAreZero: allAddsAreZero,
                    onAdd: {
                        onConfirmAdd()
                    },
                    onCancel: {
                        Haptics.lightImpact()
                        addWater = 0
                        addCaffeine = 0
                        addFoodKcal = 0
                        addSleepHours = 0
                        withAnimation { isEditing = false }
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale,
                    removal: .scale
                ))
                .animation(.snappy(duration: 0.25), value: isEditing)
            }
        }
    }
}

