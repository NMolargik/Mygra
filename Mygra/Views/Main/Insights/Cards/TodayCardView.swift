//
//  TodayCardView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI

struct TodayCardView: View {
    // Health summary
    let isAuthorized: Bool
    let latestData: HealthData?
    let useMetricUnits: Bool

    // Quick Add expand/collapse
    @Binding var isQuickAddExpanded: Bool

    // Intake editor bindings/state
    @Binding var addWater: Double
    @Binding var addCaffeine: Double
    @Binding var addCalories: Double
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
                .buttonStyle(.bordered)
                .accessibilityLabel(isQuickAddExpanded ? "Hide Quick Add" : "Show Quick Add")
            }

            if let data = latestData {
                // Precompute display strings so we can use them both for value and as stable tokens
                let waterStr = waterDisplay(from: data)
                let sleepStr = data.sleepHours.map { String(format: "%.1f h", $0) } ?? "—"
                let foodStr = data.energyKilocalories.map { "\(Int($0)) cal" } ?? "—"
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
                    addCalories: $addCalories,
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
