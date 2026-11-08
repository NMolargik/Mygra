//
//  DashboardView.swift
//  MygraFeatureDashboard
//
//  Weather, the assistant entry, Quick Bits, and today's Health stats with Quick Add (a
//  single compact row until Health is connected, so insights always lead).
//  The assistant and Quick Bits are Mygra Plus; free users see locked cards that open
//  the paywall with the feature as context.
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
    @Environment(CycleDataModel.self) private var cycleData
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(MigraineDataModel.self) private var migraineData
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    @State private var viewModel = ViewModel()

    public init() {}

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    public var body: some View {
        ScrollViewReader { proxy in
            scrollContent
                #if DEBUG
                .task {
                    // Screenshots: `-MygraDebugDashboardScroll pressure|cycle` scrolls to a card.
                    guard let anchor = UserDefaults.standard.string(forKey: "MygraDebugDashboardScroll") else { return }
                    try? await Task.sleep(for: .milliseconds(800))
                    proxy.scrollTo(anchor, anchor: UserDefaults.standard.bool(forKey: "MygraDebugScrollBottom") ? .bottom : .top)
                }
                #endif
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.Space.lg) {
                StreakHeaderView(recency: MigraineRecency.of(migraineData.migraines, hasOngoing: migraineData.ongoingMigraine != nil), total: migraineData.migraines.count)

                FinishLoggingCard()

                if isRegularWidth {
                    HStack(alignment: .top, spacing: Brand.Space.lg) {
                        VStack(spacing: Brand.Space.lg) {
                            MedicationOveruseCard()
                            weatherCard
                            assistantCard
                        }
                        VStack(spacing: Brand.Space.lg) {
                            quickBits
                            todayCard
                        }
                    }
                } else {
                    MedicationOveruseCard()
                    weatherCard
                    assistantCard
                    quickBits
                    todayCard
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
            await cycleData.refresh()
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
            },
            pressure: subscription.gate.unlocks(.weatherRisk)
                ? PressureInputs(samples: weatherManager.pressureSeries, attackStarts: migraineData.migraines.map(\.startDate))
                : nil
        )
        .id("pressure")
    }

    @ContentBuilder
    private var assistantCard: some View {
        if #available(iOS 26.0, *) {
            if insights.supportsAppleIntelligence {
                if insights.canUseIntelligence {
                    IntelligenceCardView {
                        Haptics.lightImpact()
                        viewModel.isShowingAssistant = true
                        Task { await insights.startChat() }
                    }
                } else {
                    PlusLockedCard(feature: .assistant) {
                        Haptics.lightImpact()
                        paywall.present(.assistant)
                    }
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

    @ContentBuilder
    private var quickBits: some View {
        if insights.canViewQuickBits {
            QuickBitsSectionView(cycleResult: cycleData.result(for: migraineData.migraines)) {
                Haptics.lightImpact()
                insights.refresh()
            }
            .id("cycle")
        } else {
            PlusLockedCard(feature: .quickBits) {
                Haptics.lightImpact()
                paywall.present(.quickBits)
            }
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

/// The one place the app says how long it has been: the last migraine in plain relative
/// words (or the migraine-free streak, or the ongoing state), with a quiet lifetime count.
/// The floating pill carries only the Log action, so this is never repeated.
private struct StreakHeaderView: View {
    let recency: MigraineRecency
    let total: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Brand.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                switch recency {
                case .ongoing:
                    Text("Migraine in progress")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(LinearGradient.mygraHorizontal)
                    Text("Hang in there. Update your log as it changes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                case .none:
                    Text("Welcome to Mygra")
                        .font(.title2.weight(.bold))
                    Text("Log your first migraine to start seeing patterns.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                case .withinHour:
                    title(Text("Last migraine less than an hour ago"))
                    totalLine
                case .hoursAgo(let hours):
                    title(Text("Last migraine \(hours) hours ago"))
                    totalLine
                case .daysAgo(let days):
                    title(Text("Last migraine \(days) days ago"))
                    totalLine
                case .migraineFree(let days):
                    title(Text("No migraines in \(days) days"), accent: true)
                    totalLine
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Brand.Space.xs)
        .accessibilityElement(children: .combine)
    }

    @ContentBuilder
    private func title(_ text: Text, accent: Bool = false) -> some View {
        if accent {
            text.font(.title2.weight(.bold)).foregroundStyle(LinearGradient.mygraHorizontal)
        } else {
            text.font(.title2.weight(.bold))
        }
    }

    private var totalLine: some View {
        Text("\(total) logged in total")
            .font(.subheadline)
            .foregroundStyle(.secondary)
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
