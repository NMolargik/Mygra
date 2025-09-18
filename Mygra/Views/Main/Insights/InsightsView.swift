//
//  InsightsView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import WeatherKit

struct InsightsView: View {
    @Environment(InsightManager.self) private var insightManager: InsightManager
    @Environment(HealthManager.self) private var healthManager: HealthManager
    @Environment(WeatherManager.self) private var weatherManager: WeatherManager

    @AppStorage("useMetricUnits") private var useMetricUnits: Bool = false
    
    @Binding var showingEntrySheet: Bool
    @State private var viewModel: InsightsView.ViewModel = InsightsView.ViewModel()

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
                    
                    if insightManager.intelligenceManager.supportsAppleIntelligence {
                        IntelligenceCardView(
                            onOpen: {
                                Haptics.lightImpact()
                                viewModel.isShowingMigraineAssistant = true
                                Task { await insightManager.startCounselorChat() }
                            }
                        )
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
                MigraineAssistantView()
                    .environment(insightManager)
                    .ignoresSafeArea()
            }
            .onChange(of: viewModel.isQuickAddExpanded) { _, _ in
                Haptics.lightImpact()
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
