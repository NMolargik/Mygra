//
//  InsightsView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import WeatherKit

struct InsightsView: View {
    @Binding var showingEntrySheet: Bool

    @Environment(InsightManager.self) private var insightManager: InsightManager
    @Environment(HealthManager.self) private var healthManager: HealthManager
    @Environment(WeatherManager.self) private var weatherManager: WeatherManager
    @Environment(MigraineManager.self) private var migraineManager: MigraineManager

    @AppStorage("useMetricUnits") private var useMetricUnits: Bool = false
    
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
                            lightTap()
                            Task { await weatherManager.refresh() }
                        }
                    )
                    
                    if insightManager.intelligenceManager.supportsAppleIntelligence {
                        IntelligenceCardView(
                            onOpen: {
                                lightTap()
                                viewModel.isShowingMigraineAssistant = true
                                Task { await insightManager.startCounselorChat() }
                            }
                        )
                    }
                    
                    TodayCardView(
                        isAuthorized: healthManager.isAuthorized,
                        latestData: healthManager.latestData,
                        useMetricUnits: useMetricUnits,
                        isQuickLogExpanded: $viewModel.isQuickLogExpanded,
                        // Intake bindings
                        addWater: $viewModel.addWater,
                        addCaffeine: $viewModel.addCaffeine,
                        addCalories: $viewModel.addCalories,
                        addSleepHours: $viewModel.addSleepHours,
                        isSavingIntake: viewModel.isSavingIntake,
                        intakeError: viewModel.intakeError,
                        allIntakeAddsAreZero: viewModel.allIntakeAddsAreZero,
                        // Actions
                        onConnectHealth: {
                            lightTap()
                            Task { await healthManager.requestAuthorization() }
                        },
                        onRefreshHealth: {
                            lightTap()
                            Task { await healthManager.refreshLatestForToday() }
                        },
                        onSaveIntake: {
                            lightTap()
                            Task { await saveIntake() }
                        },
                        onCancelIntake: {
                            lightTap()
                            viewModel.resetIntakeInputs()
                        }
                    )

                    QuickBitsSectionView(
                        insights: insightManager.insights,
                        isRefreshing: insightManager.isRefreshing,
                        errors: insightManager.errors,
                        onRefresh: {
                            lightTap()
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
                successTap()
            }
            .task {
                await initialLoadIfNeeded()
            }
            .fullScreenCover(isPresented: $viewModel.isShowingMigraineAssistant) {
                MigraineAssistantView()
                    .environment(insightManager)
                    .ignoresSafeArea()
            }
            // Haptics on expand/collapse of Quick Log
            .onChange(of: viewModel.isQuickLogExpanded) { _, _ in
                lightTap()
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
            if viewModel.addCalories > 0 {
                try await healthManager.saveEnergy(kcal: viewModel.addCalories)
            }
            if viewModel.addSleepHours > 0 {
                // Save a simple sleep interval ending now
                let end = Date()
                let start = end.addingTimeInterval(-viewModel.addSleepHours * 3600.0)
                try await healthManager.saveSleep(from: start, to: end)
            }

            viewModel.resetIntakeInputs()
            await healthManager.refreshLatestForToday()
            successTap()
        } catch {
            viewModel.intakeError = error.localizedDescription
            errorTap()
        }
    }

    private func initialLoadIfNeeded() async {
        async let a: () = insightManager.refresh()
        async let b: Void = weatherManager.refresh()
        async let c: Void = healthManager.refreshLatestForToday()
        _ = await (a, b, c)
        // No haptic here to avoid surprise on first open
    }

    private func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await insightManager.refresh() }
            group.addTask { await weatherManager.refresh() }
            group.addTask { await healthManager.refreshLatestForToday() }
        }
    }

    // MARK: - Haptics

    private func lightTap() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        #endif
    }

    private func successTap() {
        #if os(iOS)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif
    }

    private func errorTap() {
        #if os(iOS)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.error)
        #endif
    }
}

