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
                    Text(String(format: "+%.1f h", addSleepHours))
                        .monospacedDigit()
                        .frame(width: 90, alignment: .trailing)
                }
            }
            
            HStack {
                Spacer()
                Button(isSaving ? "Adding..." : "Add") {
                    onAdd()
                }
                .disabled(isSaving || allAddsAreZero)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button("Cancel") {
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
}
