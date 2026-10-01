//
//  TodayCardView.swift
//  MygraFeatureDashboard
//
//  Today's Health stats (per the user's dashboard stat preferences) with the Quick Add
//  intake editor.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

struct TodayCardView: View {
    let isAuthorized: Bool
    let latestData: HealthData?
    let useMetricUnits: Bool

    @Binding var isQuickAddExpanded: Bool
    @Binding var additions: IntakeAdditions
    let isSavingIntake: Bool
    let intakeError: String?

    let onConnectHealth: () -> Void
    let onRefreshHealth: () -> Void
    let onSaveIntake: () -> Void
    let onCancelIntake: () -> Void

    @State private var showHealthSourceInfo = false

    // Visibility toggles are observed individually so the card updates live; the order
    // is one JSON preference. `DashboardStat` owns the rules for both.
    @AppStorage(AppStorageKeys.showWaterStat) private var showWater = true
    @AppStorage(AppStorageKeys.showSleepStat) private var showSleep = true
    @AppStorage(AppStorageKeys.showFoodStat) private var showFood = true
    @AppStorage(AppStorageKeys.showCaffeineStat) private var showCaffeine = true
    @AppStorage(AppStorageKeys.showStepsStat) private var showSteps = false
    @AppStorage(AppStorageKeys.showHeartRateStat) private var showHeartRate = false
    @AppStorage(AppStorageKeys.showOxygenStat) private var showOxygen = false
    @AppStorage(AppStorageKeys.showGlucoseStat) private var showGlucose = false
    @AppStorage(AppStorageKeys.dashboardStatOrder) private var statOrderData: Data?

    var body: some View {
        if isAuthorized {
            authorizedCard
        } else {
            connectCard
        }
    }

    private var authorizedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Today", systemImage: "calendar")
                    .font(.headline)
                Spacer()
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
                .hoverHighlight()
                .accessibilityLabel(isQuickAddExpanded ? "Hide Quick Add" : "Show Quick Add")
                .accessibilityHint("Opens intake editor to log water, caffeine, food, or sleep")
            }

            if let data = latestData {
                let stats = visibleStats
                if stats.isEmpty {
                    Text("No stats selected. Choose dashboard stats in Settings.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                        .padding(.top, 4)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Brand.Space.md)], spacing: Brand.Space.md) {
                        ForEach(stats) { stat in
                            StatTileView(
                                title: stat.displayName,
                                value: displayValue(for: stat, data: data),
                                systemImage: stat.systemImage,
                                color: stat.color
                            )
                        }
                    }
                    .animation(.snappy, value: stats)
                }
            } else {
                HStack {
                    Text("No health data yet for today.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Fetch", action: onRefreshHealth)
                        .glassActionButton(prominent: false)
                        .controlSize(.small)
                }
                .padding(.top, 4)
            }

            if isQuickAddExpanded {
                VStack(spacing: 0) {
                    Divider().padding(.vertical, 2)
                    IntakeEditorView(
                        additions: $additions,
                        isSaving: isSavingIntake,
                        errorMessage: intakeError,
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
            Button("OK") {}
        } message: {
            Text("These values are read from Apple Health. Use the Quick Add button to log intake, or add data directly in the Health app.")
        }
    }

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Today", systemImage: "calendar")
                    .font(.headline)
                Spacer()
                Button(action: onConnectHealth) {
                    Label("Connect Health", systemImage: "heart.fill")
                }
                .glassActionButton(tint: .pink)
                .hoverHighlight()
            }
            Text("Connect Apple Health to see your daily stats.")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .cardSurface()
    }

    // MARK: - Stats

    private var visibleStats: [DashboardStat] {
        DashboardStat.order(from: statOrderData).filter(isVisible)
    }

    private func isVisible(_ stat: DashboardStat) -> Bool {
        switch stat {
        case .water: showWater
        case .sleep: showSleep
        case .food: showFood
        case .caffeine: showCaffeine
        case .steps: showSteps
        case .restingHeartRate: showHeartRate
        case .bloodOxygen: showOxygen
        case .bloodGlucose: showGlucose
        case .topTriggers: false
        }
    }

    private func displayValue(for stat: DashboardStat, data: HealthData) -> String {
        let dash = "—"
        switch stat {
        case .water:
            if useMetricUnits {
                return data.waterLiters.map { String(format: "%.1f L", $0) } ?? dash
            }
            return data.waterOunces.map { String(format: "%.0f oz", $0) } ?? dash
        case .sleep:
            return data.sleepHours.map { String(format: "%.1f h", $0) } ?? dash
        case .food:
            guard let kcal = data.energyKilocalories else { return dash }
            return useMetricUnits ? "\(Int((kcal * UnitConversion.kilocaloriesToKilojoules).rounded())) kJ" : "\(Int(kcal)) cal"
        case .caffeine:
            return data.caffeineMg.map { "\(Int($0)) mg" } ?? dash
        case .steps:
            return data.stepCount.map { $0.formatted() } ?? dash
        case .restingHeartRate:
            return data.restingHeartRate.map { "\($0) bpm" } ?? dash
        case .bloodOxygen:
            return data.bloodOxygenPercent.map { String(format: "%.0f%%", $0 * 100) } ?? dash
        case .bloodGlucose:
            guard let glucose = data.glucoseMgPerdL else { return dash }
            return useMetricUnits ? String(format: "%.1f mmol/L", glucose / UnitConversion.glucoseMgDlToMmolL) : String(format: "%.0f mg/dL", glucose)
        case .topTriggers:
            return dash
        }
    }
}

private struct VerticalScaleModifier: ViewModifier {
    let scaleY: CGFloat
    let anchor: UnitPoint
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: scaleY, anchor: anchor)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    static var verticalScaleFromTop: AnyTransition {
        .modifier(
            active: VerticalScaleModifier(scaleY: 0.001, anchor: .top, opacity: 0),
            identity: VerticalScaleModifier(scaleY: 1.0, anchor: .top, opacity: 1)
        )
    }
}

#if DEBUG
#Preview("Expanded Quick Add") {
    struct Wrapper: View {
        @State var expanded = true
        @State var additions = IntakeAdditions(waterLiters: 0.5)
        var body: some View {
            TodayCardView(
                isAuthorized: true,
                latestData: HealthData(waterLiters: 1.2, sleepHours: 6.5, energyKilocalories: 1800, caffeineMg: 120),
                useMetricUnits: false,
                isQuickAddExpanded: $expanded,
                additions: $additions,
                isSavingIntake: false,
                intakeError: nil,
                onConnectHealth: {},
                onRefreshHealth: {},
                onSaveIntake: {},
                onCancelIntake: {}
            )
            .padding()
        }
    }
    return Wrapper()
}
#endif

#if DEBUG
#Preview("Not Authorized") {
    TodayCardView(
        isAuthorized: false,
        latestData: nil,
        useMetricUnits: false,
        isQuickAddExpanded: .constant(false),
        additions: .constant(.none),
        isSavingIntake: false,
        intakeError: nil,
        onConnectHealth: {},
        onRefreshHealth: {},
        onSaveIntake: {},
        onCancelIntake: {}
    )
    .padding()
}
#endif
#endif
