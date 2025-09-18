//
//  IntakeEditorView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import SwiftUI

struct IntakeEditorView: View {
    @Binding var addWater: Double
    @Binding var addCaffeine: Double
    @Binding var addFood: Double
    @Binding var addSleepHours: Double

    // Display/config
    var useMetricUnits: Bool
    var waterRange: ClosedRange<Double>
    var waterStep: Double
    var waterDisplay: (Double) -> String

    // Status/flags
    var isSaving: Bool
    var errorMessage: String?
    var allAddsAreZero: Bool

    // Actions
    var onAdd: () -> Void
    var onCancel: () -> Void

    // Simple debounce flags to reduce slider haptic spam
    @State private var waterHapticGate = false
    @State private var caffeineHapticGate = false
    @State private var caloriesHapticGate = false
    @State private var sleepHapticGate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let msg = errorMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Water
                HStack(alignment: .center) {
                    Image(systemName: "drop.fill").foregroundStyle(.blue.gradient)
                        .frame(width: 30)
                    Slider(value: $addWater, in: waterRange, step: waterStep)
                        .tint(.blue)
                        .onChange(of: addWater) { _, _ in sliderTick(\.waterHapticGate) }
                    Text(waterDisplay(addWater))
                        .monospacedDigit()
                        .frame(width: 90, alignment: .trailing)
                }
                
                // Caffeine
                HStack(alignment: .center) {
                    Image(systemName: "cup.and.saucer.fill").foregroundStyle(.brown.gradient)
                        .frame(width: 30)
                    Slider(value: $addCaffeine, in: 0...1000, step: 10)
                        .tint(.brown)
                        .onChange(of: addCaffeine) { _, _ in sliderTick(\.caffeineHapticGate) }
                    Text("+\(Int(addCaffeine)) mg")
                        .monospacedDigit()
                        .frame(width: 90, alignment: .trailing)
                }
                
                // Energy (Calories/Joules)
                HStack(alignment: .center) {
                    Image(systemName: "fork.knife").foregroundStyle(.orange.gradient)
                        .frame(width: 30)

                    // When metric units are on, present kilojoules; otherwise present kilocalories.
                    if useMetricUnits {
                        // Present kJ to the user, but keep `addFood` stored as kcal under the hood.
                        // 1 kcal = 4.184 kJ
                        Slider(
                            value: Binding(
                                get: { addFood * 4.184 },
                                set: { addFood = $0 / 4.184 }
                            ),
                            in: 0...(2500.0 * 4.184),
                            step: 50.0 * 4.184
                        )
                        .tint(.orange)
                        .onChange(of: addFood) { _, _ in sliderTick(\.caloriesHapticGate) }

                        Text("+\(Int((addFood * 4.184).rounded())) kJ")
                            .monospacedDigit()
                            .frame(width: 90, alignment: .trailing)
                    } else {
                        Slider(value: $addFood, in: 0...2500, step: 50)
                            .tint(.orange)
                            .onChange(of: addFood) { _, _ in sliderTick(\.caloriesHapticGate) }

                        Text("+\(Int(addFood)) kcal")
                            .monospacedDigit()
                            .frame(width: 90, alignment: .trailing)
                    }
                }
                
                // Sleep
                HStack(alignment: .center) {
                    Image(systemName: "bed.double.fill").foregroundStyle(.indigo.gradient)
                        .frame(width: 30)
                    Slider(value: $addSleepHours, in: 0...12, step: 0.5)
                        .tint(.indigo)
                        .onChange(of: addSleepHours) { _, _ in sliderTick(\.sleepHapticGate) }
                    Text(String(format: "+%.1f h", addSleepHours))
                        .monospacedDigit()
                        .frame(width: 90, alignment: .trailing)
                }
            }
            
            HStack {
                Spacer()
                Button(isSaving ? "Adding..." : "Add") {
                    // Only fire success haptic if the action is actually going to run
                    if !isSaving && !allAddsAreZero {
                        Haptics.success()
                    } else {
                        Haptics.lightImpact()
                    }
                    onAdd()
                }
                .disabled(isSaving || allAddsAreZero)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button("Cancel") {
                    Haptics.lightImpact()
                    onCancel()
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.top, 6)
    }

    // MARK: - Haptics

    // Tasteful, debounced tick to avoid spamming during continuous slider drags
    @MainActor
    private func sliderTick(_ gateKeyPath: ReferenceWritableKeyPath<IntakeEditorView, Bool>) {
        // If gate is already open, do nothing
        if self[keyPath: gateKeyPath] { return }

        // Open gate
        self[keyPath: gateKeyPath] = true

        Haptics.lightImpact()

        // Close gate after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self[keyPath: gateKeyPath] = false
        }
    }
}

#if DEBUG
import SwiftUI

struct IntakeEditorView_Previews: PreviewProvider {
    // Wrapper to supply @State bindings required by IntakeEditorView
    struct ImperialWrapper: View {
        @State var addWater: Double = 16
        @State var addCaffeine: Double = 120
        @State var addFood: Double = 500
        @State var addSleepHours: Double = 1.0
        
        var body: some View {
            IntakeEditorView(
                addWater: $addWater,
                addCaffeine: $addCaffeine,
                addFood: $addFood,
                addSleepHours: $addSleepHours,
                // Display/config
                useMetricUnits: false,
                waterRange: 0...128,
                waterStep: 1,
                waterDisplay: { value in "+\(Int(value)) oz" },
                // Status/flags
                isSaving: false,
                errorMessage: nil,
                allAddsAreZero: false,
                // Actions
                onAdd: {},
                onCancel: {}
            )
            .padding()
            .previewDisplayName("Imperial (kcal)")
        }
    }

    struct MetricWrapper: View {
        @State var addWater: Double = 250
        @State var addCaffeine: Double = 200
        @State var addFood: Double = 600
        @State var addSleepHours: Double = 0.5
        
        var body: some View {
            IntakeEditorView(
                addWater: $addWater,
                addCaffeine: $addCaffeine,
                addFood: $addFood,
                addSleepHours: $addSleepHours,
                // Display/config
                useMetricUnits: true,
                waterRange: 0...3000,
                waterStep: 50,
                waterDisplay: { value in "+\(Int(value)) mL" },
                // Status/flags
                isSaving: false,
                errorMessage: "Example error",
                allAddsAreZero: false,
                // Actions
                onAdd: {},
                onCancel: {}
            )
            .padding()
            .previewDisplayName("Metric + Error Banner (kJ)")
        }
    }

    static var previews: some View {
        Group {
            ImperialWrapper()
            MetricWrapper()
        }
    }
}
#endif
