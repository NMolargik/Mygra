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
    @Binding var addCalories: Double
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
                    Image(systemName: "drop.fill").foregroundStyle(.blue)
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
                    Image(systemName: "cup.and.saucer.fill").foregroundStyle(.brown)
                        .frame(width: 30)
                    Slider(value: $addCaffeine, in: 0...1000, step: 10)
                        .tint(.brown)
                        .onChange(of: addCaffeine) { _, _ in sliderTick(\.caffeineHapticGate) }
                    Text("+\(Int(addCaffeine)) mg")
                        .monospacedDigit()
                        .frame(width: 90, alignment: .trailing)
                }
                
                // Calories
                HStack(alignment: .center) {
                    Image(systemName: "fork.knife").foregroundStyle(.orange)
                        .frame(width: 30)
                    Slider(value: $addCalories, in: 0...2500, step: 50)
                        .tint(.orange)
                        .onChange(of: addCalories) { _, _ in sliderTick(\.caloriesHapticGate) }
                    Text("+\(Int(addCalories)) cal")
                        .monospacedDigit()
                        .frame(width: 90, alignment: .trailing)
                }
                
                // Sleep
                HStack(alignment: .center) {
                    Image(systemName: "bed.double.fill").foregroundStyle(.indigo)
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
                        successHaptic()
                    } else {
                        lightImpact()
                    }
                    onAdd()
                }
                .disabled(isSaving || allAddsAreZero)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button("Cancel") {
                    lightImpact()
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

    private func lightImpact() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
    }

    private func successHaptic() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    // Tasteful, debounced tick to avoid spamming during continuous slider drags
    @MainActor
    private func sliderTick(_ gateKeyPath: ReferenceWritableKeyPath<IntakeEditorView, Bool>) {
        // If gate is already open, do nothing
        if self[keyPath: gateKeyPath] { return }

        // Open gate
        self[keyPath: gateKeyPath] = true

        lightImpact()

        // Close gate after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self[keyPath: gateKeyPath] = false
        }
    }
}
