//
//  TodayCardView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI

struct TodayCardView: View {
    let isAuthorized: Bool
    let latestData: HealthData?
    let useMetricUnits: Bool

    @Binding var isQuickAddExpanded: Bool
    @Binding var addWater: Double
    @Binding var addCaffeine: Double
    @Binding var addFood: Double
    @Binding var addSleepHours: Double
    
    let isSavingIntake: Bool
    let intakeError: String?
    let allIntakeAddsAreZero: Bool

    // Actions
    let onConnectHealth: () -> Void
    let onRefreshHealth: () -> Void
    let onSaveIntake: () -> Void
    let onCancelIntake: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Today", systemImage: "calendar")
                    .font(.headline)

                Spacer()

                if !isAuthorized {
                    Button("Connect Health", action: onConnectHealth)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                } else {
                    Button(action: onRefreshHealth) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isQuickAddExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Quick Add")
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isQuickAddExpanded ? 180 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isQuickAddExpanded)
                    }
                }
                .tint(.red)
                .buttonStyle(.bordered)
                .accessibilityLabel(isQuickAddExpanded ? "Hide Quick Add" : "Show Quick Add")
            }

            if let data = latestData {
                // Precompute display strings so we can use them both for value and as stable tokens
                let waterStr = waterDisplay(from: data)
                let sleepStr = data.sleepHours.map { String(format: "%.1f h", $0) } ?? "—"
                let foodStr: String = {
                    guard let kcal = data.energyKilocalories else { return "—" }
                    if useMetricUnits {
                        let kJ = (kcal * 4.184).rounded()
                        return "\(Int(kJ)) kJ"
                    } else {
                        return "\(Int(kcal)) cal"
                    }
                }()
                let caffeineStr = data.caffeineMg.map { "\(Int($0)) mg" } ?? "—"

                HStack(spacing: 12) {
                    StatTileView(
                        title: "Water",
                        value: waterStr,
                        systemImage: "drop.fill",
                        color: .blue,
                        valueToken: AnyHashable(waterStr)
                    )
                    StatTileView(
                        title: "Sleep",
                        value: sleepStr,
                        systemImage: "bed.double.fill",
                        color: .indigo,
                        valueToken: AnyHashable(sleepStr)
                    )
                }
                HStack(spacing: 12) {
                    StatTileView(
                        title: "Food",
                        value: foodStr,
                        systemImage: "fork.knife",
                        color: .orange,
                        valueToken: AnyHashable(foodStr)
                    )
                    StatTileView(
                        title: "Caffeine",
                        value: caffeineStr,
                        systemImage: "cup.and.saucer.fill",
                        color: .brown,
                        valueToken: AnyHashable(caffeineStr)
                    )
                }
            } else {
                HStack {
                    Text("No health data yet for today.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Fetch", action: onRefreshHealth)
                        .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }

            if isQuickAddExpanded {
                Divider().padding(.vertical, 2)

                IntakeEditorView(
                    addWater: $addWater,
                    addCaffeine: $addCaffeine,
                    addFood: $addFood,
                    addSleepHours: $addSleepHours,
                    useMetricUnits: useMetricUnits,
                    waterRange: useMetricUnits ? 0...2.5 : 0...(2.5 * 33.814 / 33.814),
                    waterStep: 0.1,
                    waterDisplay: { liters in
                        if useMetricUnits {
                            return String(format: "+%.1f L", liters)
                        } else {
                            let oz = liters * 33.814
                            return String(format: "+%.0f oz", oz)
                        }
                    },
                    isSaving: isSavingIntake,
                    errorMessage: intakeError,
                    allAddsAreZero: allIntakeAddsAreZero,
                    onAdd: onSaveIntake,
                    onCancel: onCancelIntake
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipped()
        .accessibilityElement(children: .contain)
    }

    private func waterDisplay(from data: HealthData) -> String {
        if useMetricUnits {
            if let liters = data.waterLiters {
                return String(format: "%.1f L", liters)
            } else { return "—" }
        } else {
            if let oz = data.waterOunces {
                return String(format: "%.0f oz", oz)
            } else { return "—" }
        }
    }
}

// MARK: - Previews

private struct TodayCardPreviewWrapper: View {
    // Local state to satisfy TodayCardView bindings
    @State var isQuickAddExpanded: Bool = false
    @State var addWater: Double = 0.5     // liters (used for imperial too; formatter converts)
    @State var addCaffeine: Double = 120
    @State var addFood: Double = 400
    @State var addSleepHours: Double = 0.5

    // Config
    var isAuthorized: Bool
    var latestData: HealthData?
    var useMetricUnits: Bool
    var isSavingIntake: Bool = false
    var intakeError: String? = nil
    var allIntakeAddsAreZero: Bool = false

    var body: some View {
        TodayCardView(
            isAuthorized: isAuthorized,
            latestData: latestData,
            useMetricUnits: useMetricUnits,
            isQuickAddExpanded: $isQuickAddExpanded,
            addWater: $addWater,
            addCaffeine: $addCaffeine,
            addFood: $addFood,
            addSleepHours: $addSleepHours,
            isSavingIntake: isSavingIntake,
            intakeError: intakeError,
            allIntakeAddsAreZero: allIntakeAddsAreZero,
            onConnectHealth: {},
            onRefreshHealth: {},
            onSaveIntake: {},
            onCancelIntake: { isQuickAddExpanded = false }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

#Preview("Collapsed, Not Authorized") {
    TodayCardPreviewWrapper(
        isAuthorized: false,
        latestData: nil,
        useMetricUnits: false
    )
}

#Preview("Expanded Quick Add (Imperial)") {
    TodayCardPreviewWrapper(
        isQuickAddExpanded: true,
        isAuthorized: true,
        latestData: nil,
        useMetricUnits: false
    )
}

#Preview("Expanded Quick Add (Metric + Error)") {
    TodayCardPreviewWrapper(
        isQuickAddExpanded: true,
        isAuthorized: true,
        latestData: nil,
        useMetricUnits: true,
        intakeError: "Example error",
        allIntakeAddsAreZero: false
    )
}

