//
//  DashboardView.swift
//  MygraFeatureDashboard
//
//  Weather, the assistant entry, today's Health stats with Quick Add, and Quick Bits.
//  On regular widths it also hosts the calendar and settings as sheets.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraServices
import MygraFeatureShared
import MygraFeatureCalendar
import MygraFeatureAssistant
import MygraFeatureSettings

public struct DashboardView: View {
    @Environment(InsightModel.self) private var insights
    @Environment(HealthManager.self) private var healthManager
    @Environment(WeatherManager.self) private var weatherManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    /// Regular-width hosts route calendar selections into their navigation stack.
    var onNavigateToMigraine: ((UUID) -> Void)?

    @State private var viewModel = ViewModel()

    public init(onNavigateToMigraine: ((UUID) -> Void)? = nil) {
        self.onNavigateToMigraine = onNavigateToMigraine
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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

                QuickBitsSectionView {
                    Haptics.lightImpact()
                    insights.refresh()
                }

                Color.clear.frame(height: 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
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
        .toolbar {
            if horizontalSizeClass == .regular {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.mediumImpact()
                        viewModel.isShowingCalendar = true
                    } label: {
                        Label("Calendar", systemImage: "calendar")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingSettings) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { viewModel.isShowingSettings = false }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $viewModel.isShowingCalendar) {
            NavigationStack {
                MigraineCalendarView { migraineID in
                    viewModel.isShowingCalendar = false
                    onNavigateToMigraine?(migraineID)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { viewModel.isShowingCalendar = false }
                    }
                }
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
        var isShowingCalendar = false
        var isShowingSettings = false

        func resetIntake() {
            additions = .none
            intakeError = nil
        }
    }
}

#Preview("Dashboard") {
    NavigationStack {
        DashboardView()
            .navigationTitle("Mygra")
    }
    .previewEnvironment()
}
#endif
