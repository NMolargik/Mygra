//
//  DashboardView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import WeatherKit
import SwiftData

struct DashboardView: View {
    @Environment(InsightManager.self) private var insightManager: InsightManager
    @Environment(HealthManager.self) private var healthManager: HealthManager
    @Environment(WeatherManager.self) private var weatherManager: WeatherManager
    @Environment(MigraineManager.self) private var migraineManager: MigraineManager
    @Environment(TagManager.self) private var tagManager: TagManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    @Binding var showingEntrySheet: Bool
    /// Callback to navigate to a migraine in the main navigation stack (used when calendar is in sheet)
    var onNavigateToMigraine: ((UUID) -> Void)? = nil
    var deleteAllData: () -> Void
    
    @State private var viewModel: DashboardView.ViewModel = DashboardView.ViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    WeatherCardView(
                        temperatureString: weatherManager.temperatureString,
                        pressureString: weatherManager.pressureString,
                        humidityPercentString: weatherManager.humidityPercentString,
                        condition: weatherManager.condition,
                        lastUpdated: weatherManager.lastUpdated,
                        isFetching: weatherManager.isFetching,
                        error: weatherManager.error,
                        onRefresh: {
                            Haptics.lightImpact()
                            Task { await weatherManager.refresh() }
                        },
                        locationString: weatherManager.locationString
                    )
                    
                    
                    if #available(iOS 26.0, *) {
                        if insightManager.intelligenceManager.supportsAppleIntelligence {
                            IntelligenceCardView(
                                onOpen: {
                                    Haptics.lightImpact()
                                    viewModel.isShowingMigraineAssistant = true
                                    Task { await insightManager.startCounselorChat() }
                                }
                            )
                        }
                    } else {
                        IntelligenceUpgradeCardView()
                    }
                    
                    TodayCardView(
                        isAuthorized: healthManager.isAuthorized,
                        latestData: healthManager.latestData,
                        useMetricUnits: useMetricUnits,
                        isQuickAddExpanded: $viewModel.isQuickAddExpanded,
                        addWater: $viewModel.addWater,
                        addCaffeine: $viewModel.addCaffeine,
                        addFood: $viewModel.addFood,
                        addSleepHours: $viewModel.addSleepHours,
                        isSavingIntake: viewModel.isSavingIntake,
                        intakeError: viewModel.intakeError,
                        allIntakeAddsAreZero: viewModel.allIntakeAddsAreZero,
                        // Actions
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
                            viewModel.resetIntakeInputs()
                        }
                    )

                    QuickBitsSectionView(
                        insights: insightManager.insights,
                        isRefreshing: insightManager.isRefreshing,
                        errors: insightManager.errors,
                        onRefresh: {
                            Haptics.lightImpact()
                            Task { await insightManager.refresh() }
                        }
                    )

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
                await initialLoadIfNeeded()
            }
            .fullScreenCover(isPresented: $viewModel.isShowingMigraineAssistant) {
                if #available(iOS 26.0, *) {
                    MigraineAssistantView()
                        .environment(insightManager)
                        .ignoresSafeArea()
                }
            }
            .onChange(of: viewModel.isQuickAddExpanded) { _, _ in
                Haptics.lightImpact()
            }
            .toolbar {
                if horizontalSizeClass == .regular {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Haptics.mediumImpact()
                            viewModel.isShowingCalendar.toggle()
                        } label: {
                            Label("Calendar", systemImage: "calendar")
                        }
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.isShowingSettingSheet.toggle()
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingSettingSheet) {
                NavigationStack {
                    SettingsView(
                        onDeletionTriggered: {
                            self.deleteAllData()
                        }
                    )
                    .presentationDetents([.large])
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") {
                                viewModel.isShowingSettingSheet = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingCalendar) {
                NavigationStack {
                    MigraineCalendarView(onSelectMigraine: { migraineID in
                        viewModel.isShowingCalendar = false
                        onNavigateToMigraine?(migraineID)
                    })
                    .environment(migraineManager)
                    .environment(tagManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                viewModel.isShowingCalendar = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func saveIntake() async {
        guard !viewModel.isSavingIntake else { return }
        viewModel.isSavingIntake = true
        viewModel.intakeError = nil
        defer { viewModel.isSavingIntake = false }

        do {
            // Persist each non-zero input to HealthKit
            if viewModel.addWater > 0 {
                try await healthManager.saveWater(liters: viewModel.addWater)
            }
            if viewModel.addCaffeine > 0 {
                try await healthManager.saveCaffeine(mg: viewModel.addCaffeine)
            }
            if viewModel.addFood > 0 {
                try await healthManager.saveEnergy(kcal: viewModel.addFood)
            }
            if viewModel.addSleepHours > 0 {
                // Save a simple sleep interval ending now
                let end = Date()
                let start = end.addingTimeInterval(-viewModel.addSleepHours * 3600.0)
                try await healthManager.saveSleep(from: start, to: end)
            }

            viewModel.resetIntakeInputs()
            await healthManager.refreshLatestForToday()
            Haptics.success()
        } catch {
            viewModel.intakeError = error.localizedDescription
            Haptics.error()
        }
    }

    private func initialLoadIfNeeded() async {
        async let a: () = insightManager.refresh()
        async let b: Void = weatherManager.refresh()
        async let c: Void = healthManager.refreshLatestForToday()
        _ = await (a, b, c)
    }

    private func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await insightManager.refresh() }
            group.addTask { await weatherManager.refresh() }
            group.addTask { await healthManager.refreshLatestForToday() }
        }
    }
}

#Preview("Dashboard – Basic") {
    // Register AppStorage defaults for preview
    UserDefaults.standard.register(defaults: [
        AppStorageKeys.useMetricUnits: false
    ])

    // In-memory model container for preview
    let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: User.self, Migraine.self, WeatherData.self, HealthData.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Preview ModelContainer setup failed: \(error)")
        }
    }()

    // Lightweight managers for environment
    let previewHealthManager = HealthManager()
    let previewWeatherManager = WeatherManager()
    let previewUserManager = UserManager(context: container.mainContext)
    let previewMigraineManager = MigraineManager(context: container.mainContext, healthManager: previewHealthManager)
    let previewInsightManager = InsightManager(
        userManager: previewUserManager,
        migraineManager: previewMigraineManager,
        weatherManager: previewWeatherManager,
        healthManager: previewHealthManager
    )

    let previewTagManager = TagManager(context: container.mainContext)

    // Note: InsightManager.insights has a restricted setter; leaving insights empty for preview.

    return DashboardView(showingEntrySheet: .constant(false), deleteAllData: {})
        .modelContainer(container)
        .environment(previewInsightManager)
        .environment(previewHealthManager)
        .environment(previewWeatherManager)
        .environment(previewMigraineManager)
        .environment(previewTagManager)
}

