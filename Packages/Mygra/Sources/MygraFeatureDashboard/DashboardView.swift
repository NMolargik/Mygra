//
//  DashboardView.swift
//  MygraFeatureDashboard
//
//  Weather, the assistant entry, today's Health stats with Quick Add, and Quick Bits.
//  Cards stack on iPhone and flow into two balanced columns at regular widths (iPad
//  windows, Mac), so a resized window never shows a single stretched column.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraServices
import MygraFeatureShared
import MygraFeatureAssistant

public struct DashboardView: View {
    @Environment(InsightModel.self) private var insights
    @Environment(HealthManager.self) private var healthManager
    @Environment(WeatherManager.self) private var weatherManager
    @Environment(MigraineDataModel.self) private var migraineData
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    @State private var viewModel = ViewModel()

    public init() {}

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.Space.lg) {
                StreakHeaderView(daysSince: MigraineStatistics.streakDays(migraineData.migraines), hasOngoing: migraineData.ongoingMigraine != nil, total: migraineData.migraines.count)

                if isRegularWidth {
                    HStack(alignment: .top, spacing: Brand.Space.lg) {
                        VStack(spacing: Brand.Space.lg) {
                            weatherCard
                            assistantCard
                            todayCard
                        }
                        VStack(spacing: Brand.Space.lg) {
                            quickBits
                        }
                    }
                } else {
                    weatherCard
                    assistantCard
                    todayCard
                    quickBits
                }

                Color.clear.frame(height: Brand.Space.md)
            }
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Brand.Space.lg)
            .padding(.top, Brand.Space.sm)
        }
        .softScrollEdgesIfAvailable()
        .refreshable {
            await refreshAll()
            Haptics.success()
        }
        .task {
            await refreshAll()
        }
        .fullScreenCover(isPresented: $viewModel.isShowingAssistant) {
            MigraineAssistantView()
                .ignoresSafeArea()
        }
        .onChange(of: viewModel.isQuickAddExpanded) { _, _ in
            Haptics.lightImpact()
        }
    }

    // MARK: - Cards

    private var weatherCard: some View {
        WeatherCardView(
            reading: weatherManager.reading,
            isFetching: weatherManager.isFetching,
            error: weatherManager.error,
            locationString: weatherManager.locationString,
            onRefresh: {
                Haptics.lightImpact()
                Task { await weatherManager.refresh() }
            }
        )
    }

    @ContentBuilder
    private var assistantCard: some View {
        if #available(iOS 26.0, *) {
            if insights.supportsAppleIntelligence {
                IntelligenceCardView {
                    Haptics.lightImpact()
                    viewModel.isShowingAssistant = true
                    Task { await insights.startChat() }
                }
            }
        } else {
            IntelligenceUpgradeCardView()
        }
    }

    private var todayCard: some View {
        TodayCardView(
            isAuthorized: healthManager.isAuthorized,
            latestData: healthManager.latestData,
            useMetricUnits: useMetricUnits,
            isQuickAddExpanded: $viewModel.isQuickAddExpanded,
            additions: $viewModel.additions,
            isSavingIntake: viewModel.isSavingIntake,
            intakeError: viewModel.intakeError,
            onConnectHealth: {
                Haptics.lightImpact()
                Task { await healthManager.requestAuthorization() }
            },
            onRefreshHealth: {
                Haptics.lightImpact()
                Task { await healthManager.refreshLatestForToday() }
            },
            onSaveIntake: {
                Haptics.lightImpact()
                Task { await saveIntake() }
            },
            onCancelIntake: {
                Haptics.lightImpact()
                viewModel.resetIntake()
            }
        )
    }

    private var quickBits: some View {
        QuickBitsSectionView {
            Haptics.lightImpact()
            insights.refresh()
        }
    }

    // MARK: - Actions

    private func saveIntake() async {
        guard !viewModel.isSavingIntake else { return }
        viewModel.isSavingIntake = true
        viewModel.intakeError = nil
        defer { viewModel.isSavingIntake = false }
        do {
            try await healthManager.save(viewModel.additions)
            viewModel.resetIntake()
            await healthManager.refreshLatestForToday()
            Haptics.success()
        } catch {
            viewModel.intakeError = error.localizedDescription
            Haptics.error()
        }
    }

    private func refreshAll() async {
        async let weather: Void = weatherManager.refresh()
        async let health: Void = healthManager.refreshLatestForToday()
        insights.refresh()
        _ = await (weather, health)
    }
}

extension DashboardView {
    @MainActor
    @Observable
    final class ViewModel {
        var additions = IntakeAdditions()
        var isSavingIntake = false
        var intakeError: String?
        var isQuickAddExpanded = false
        var isShowingAssistant = false

        func resetIntake() {
            additions = .none
            intakeError = nil
        }
    }
}

// MARK: - Streak header

/// The one number that matters most, up top: days since the last migraine (or the
/// ongoing state), with a quiet lifetime count.
private struct StreakHeaderView: View {
    let daysSince: Int
    let hasOngoing: Bool
    let total: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Brand.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                if hasOngoing {
                    Text("Migraine in progress")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(LinearGradient.mygraHorizontal)
                    Text("Hang in there — log updates as it changes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if total == 0 {
                    Text("Welcome to Mygra")
                        .font(.title2.weight(.bold))
                    Text("Log your first migraine to start seeing patterns.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if daysSince == 0 {
                    Text("Last migraine today")
                        .font(.title2.weight(.bold))
                    Text("Rest up — \(total) logged in total.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: Brand.Space.xs) {
                        Text(daysSince, format: .number)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LinearGradient.mygraHorizontal)
                            .contentTransition(.numericText())
                        Text(daysSince == 1 ? "day migraine-free" : "days migraine-free")
                            .font(.headline)
                    }
                    Text("\(total) logged in total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Brand.Space.xs)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Dashboard") {
    NavigationStack {
        DashboardView()
            .navigationTitle("Mygra")
    }
    .previewEnvironment()
}
#endif
#endif
