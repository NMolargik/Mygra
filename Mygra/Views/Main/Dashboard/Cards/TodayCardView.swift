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

    @State private var showHealthSourceInfo: Bool = false
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

    // MARK: - Dashboard Stat Visibility
    @AppStorage(AppStorageKeys.showWaterStat) private var showWater = true
    @AppStorage(AppStorageKeys.showSleepStat) private var showSleep = true
    @AppStorage(AppStorageKeys.showFoodStat) private var showFood = true
    @AppStorage(AppStorageKeys.showCaffeineStat) private var showCaffeine = true
    @AppStorage(AppStorageKeys.showStepsStat) private var showSteps = false
    @AppStorage(AppStorageKeys.showHeartRateStat) private var showHeartRate = false
    @AppStorage(AppStorageKeys.showOxygenStat) private var showOxygen = false
    @AppStorage(AppStorageKeys.showGlucoseStat) private var showGlucose = false

    var body: some View {
        if isAuthorized {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Today", systemImage: "calendar")
                        .font(.headline)

                    Spacer()

                    if !isAuthorized {
                        Button("Connect Health", action: onConnectHealth)
                            .buttonStyle(.borderedProminent)
                            .tint(.pink)
                    } else {
                        Button {
                            showHealthSourceInfo = true
                        } label: {
                            Label("Health Info", systemImage: "info.circle")
                        }
                        .buttonStyle(.borderless)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("About health data source")

                        Button(action: onRefreshHealth) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.mygraPurple)
                        .accessibilityLabel("Refresh health data")
                    }

                    if isAuthorized {
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
                        .glassActionButton(prominent: false)
                        .controlSize(.small)
                        .accessibilityLabel(isQuickAddExpanded ? "Hide Quick Add" : "Show Quick Add")
                        .accessibilityHint("Opens intake editor to log water, caffeine, food, or sleep")
                    }
                }

                if let data = latestData {
                    let visibleStats = buildVisibleStats()

                    if visibleStats.isEmpty {
                        Text("No stats selected. Go to Settings to select dashboard stats.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .padding(.top, 4)
                    } else {
                        // Dynamic grid that adapts to the number of visible stats
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(visibleStats, id: \.self) { stat in
                                StatTileView(
                                    title: stat.displayName,
                                    value: displayValue(for: stat, data: data),
                                    systemImage: stat.systemImage,
                                    color: stat.color,
                                    valueToken: AnyHashable(displayValue(for: stat, data: data))
                                )
                            }
                        }
                    }
                } else {
                    HStack {
                        Text("No health data yet for today.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Fetch", action: onRefreshHealth)
                            .buttonStyle(.bordered)
                            .tint(.mygraBlue)
                    }
                    .padding(.top, 4)
                }

                if isAuthorized && isQuickAddExpanded {
                    VStack(spacing: 0) {
                        Divider().padding(.vertical, 2)

                        IntakeEditorView(
                            addWater: $addWater,
                            addCaffeine: $addCaffeine,
                            addFood: $addFood,
                            addSleepHours: $addSleepHours,
                            isSaving: isSavingIntake,
                            errorMessage: intakeError,
                            allAddsAreZero: allIntakeAddsAreZero,
                            onAdd: onSaveIntake,
                            onCancel: {
                                withAnimation {
                                    onCancelIntake()
                                    isQuickAddExpanded = false
                                }
                            }
                        )
                    }
                    .transition(.verticalScaleFromTop)
                }
            }
            .padding(14)
            .cardSurface()
            .clipped()
            .accessibilityElement(children: .contain)
            .alert("About This Data", isPresented: $showHealthSourceInfo) {
                Button("OK") { }
            } message: {
                Text("These values are read from Apple Health. Use the Quick Add button to log intake, or add data directly in the Health app.")
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Today", systemImage: "calendar")
                        .font(.headline)
                    Spacer()
                    Button("Connect Health", action: onConnectHealth)
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                }
                Text("Connect Apple Health to see your daily stats.")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .cardSurface()
        }
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

    // MARK: - Dynamic Stat Helpers

    /// Returns an array of DashboardStat cases that should be visible based on user preferences.
    private func buildVisibleStats() -> [DashboardStat] {
        var stats: [DashboardStat] = []
        if showWater { stats.append(.water) }
        if showSleep { stats.append(.sleep) }
        if showFood { stats.append(.food) }
        if showCaffeine { stats.append(.caffeine) }
        if showSteps { stats.append(.steps) }
        if showHeartRate { stats.append(.restingHeartRate) }
        if showOxygen { stats.append(.bloodOxygen) }
        if showGlucose { stats.append(.bloodGlucose) }
        return stats
    }

    /// Returns the display string for a given stat from the HealthData.
    private func displayValue(for stat: DashboardStat, data: HealthData) -> String {
        switch stat {
        case .water:
            return waterDisplay(from: data)

        case .sleep:
            return data.sleepHours.map { String(format: "%.1f h", $0) } ?? "—"

        case .food:
            guard let kcal = data.energyKilocalories else { return "—" }
            if useMetricUnits {
                let kJ = (kcal * UnitConversion.kilocaloriesToKilojoules).rounded()
                return "\(Int(kJ)) kJ"
            } else {
                return "\(Int(kcal)) cal"
            }

        case .caffeine:
            return data.caffeineMg.map { "\(Int($0)) mg" } ?? "—"

        case .steps:
            return data.stepCount.map { "\($0.formatted())" } ?? "—"

        case .restingHeartRate:
            return data.restingHeartRate.map { "\($0) bpm" } ?? "—"

        case .bloodOxygen:
            guard let spo2 = data.bloodOxygenPercent else { return "—" }
            return String(format: "%.0f%%", spo2)

        case .bloodGlucose:
            guard let glucose = data.glucoseMgPerdL else { return "—" }
            if useMetricUnits {
                let mmol = glucose / UnitConversion.glucoseMgDlToMmolL
                return String(format: "%.1f mmol/L", mmol)
            } else {
                return String(format: "%.0f mg/dL", glucose)
            }

        case .topTriggers:
            // Triggers are handled separately at DashboardView level
            return "—"
        }
    }
}

fileprivate struct VerticalScaleModifier: ViewModifier {
    let scaleY: CGFloat
    let anchor: UnitPoint
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: scaleY, anchor: anchor)
            .opacity(opacity)
    }
}

fileprivate extension AnyTransition {
    static var verticalScaleFromTop: AnyTransition {
        .modifier(
            active: VerticalScaleModifier(scaleY: 0.001, anchor: .top, opacity: 0),
            identity: VerticalScaleModifier(scaleY: 1.0, anchor: .top, opacity: 1)
        )
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

