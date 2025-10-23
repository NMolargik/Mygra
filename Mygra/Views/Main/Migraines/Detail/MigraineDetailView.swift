//
//  MigraineDetailView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import SwiftUI
import WeatherKit
import SwiftData

struct MigraineDetailView: View {
    @Environment(MigraineManager.self) private var migraineManager: MigraineManager
    @Environment(InsightManager.self) private var insightManager: InsightManager
    @Environment(WeatherManager.self) private var weatherManager: WeatherManager
    @Environment(HealthManager.self) private var healthManager: HealthManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false
    
    let migraine: Migraine
    var onClose: (() -> Void)? = nil
    
    // Sheet & alert state
    @State private var showingEndSheet = false
    @State private var proposedEndDate: Date = Date()
    @State private var endError: String?
    @State private var showDeleteConfirm = false
    @State private var showingModifySheet = false
    
    @State private var showPendingWeatherAlert: Bool = false
    @State private var pendingWeatherAlertMessage: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MigraineDetailHeaderView(
                    migraine: migraine,
                    startText: DateFormatting.dateTime(migraine.startDate, useDMY: useDayMonthYearDates),
                    endText: migraine.endDate.map { DateFormatting.dateTime($0, useDMY: useDayMonthYearDates) } ?? "Ongoing",
                    durationText: headerDurationText,
                    isOngoing: migraine.isOngoing,
                    endError: endError,
                    onEndTap: {
                        proposedEndDate = defaultEndDate
                        showingEndSheet = true
                    }
                )
                
                InsightSectionView(migraine: migraine)
                
                if let note = migraine.note, !note.isEmpty {
                    NoteDetailView(note: note)
                }
                
                if !migraine.triggers.isEmpty || !migraine.customTriggers.isEmpty {
                    TriggersDetailView(triggers: migraine.triggers, customTriggers: migraine.customTriggers)
                }
                
                if let wx = migraine.weather {
                    WeatherDetailView(weather: wx, useMetricUnits: useMetricUnits)
                }
                
                if let h = migraine.health {
                    HealthDetailView(health: h, useMetricUnits: useMetricUnits)
                }
            }
            .padding()
        }
        .navigationTitle("Migraine")
        .navigationBarTitleDisplayMode(.inline)
        // iPad-only Close button in the leading position, pin in trailing
        .toolbar {
            if hSizeClass == .regular {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    migraineManager.togglePinned(migraine)
                } label: {
                    Image(systemName: migraine.pinned ? "pin.fill" : "pin")
                        .foregroundStyle(migraine.pinned ? .yellow : .secondary)
                }
                .accessibilityLabel(migraine.pinned ? "Unpin" : "Pin")
            }
            
            if !migraine.isOngoing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingModifySheet = true
                    } label: {
                        Label("Modify", systemImage: "slider.horizontal.3")
                    }
                    .tint(.green)
                    .accessibilityIdentifier("modifyMigraineButton")
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Migraine", systemImage: "trash")
                    }
                    .tint(.red)
                    .accessibilityIdentifier("deleteMigraineButton")
                }
            }
        }
        .sheet(isPresented: $showingEndSheet) {
            EndMigraineSheet(
                startDate: migraine.startDate,
                initialEndDate: defaultEndDate,
                onConfirm: { selected in
                    endError = nil
                    guard selected >= migraine.startDate else {
                        endError = "End time must be after the start time."
                        return
                    }
                    migraineManager.update(migraine) { m in
                        m.endDate = selected
                    }
                    dismiss()
                },
                onCancel: { /* simply closes */ }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingModifySheet) {
            ModifyMigraineSheetView(
                migraine: migraine,
                onCancel: {
                    showingModifySheet = false
                },
                onSave: { startDate, endDate, pain, stress, triggers, addedWater, addedCaffeine, addedFoodKcal, addedSleepHours in
                    // Persist edits and refresh via manager
                    migraineManager.update(migraine) { m in
                        m.startDate = startDate
                        m.endDate = endDate
                        m.painLevel = pain
                        m.stressLevel = stress
                        m.triggers = Array(triggers)
                    }

                    // Persist staged intake adds to Apple Health at the migraine's start time
                    Task {
                        do {
                            if addedWater > 0 {
                                // addWater is stored in liters; round to nearest milliliter for HealthKit
                                let liters = (addedWater * 1000).rounded() / 1000
                                try await healthManager.saveWater(liters: liters, on: startDate)
                            }
                            if addedCaffeine > 0 {
                                try await healthManager.saveCaffeine(mg: round(addedCaffeine), on: startDate)
                            }
                            if addedFoodKcal > 0 {
                                try await healthManager.saveEnergy(kcal: round(addedFoodKcal), on: startDate)
                            }
                            if addedSleepHours > 0 {
                                let end = startDate
                                let begin = end.addingTimeInterval(-addedSleepHours * 3600.0)
                                try await healthManager.saveSleep(from: begin, to: end)
                            }
                        } catch {
                            print("[Detail] Failed to save staged HealthKit intake: \(error)")
                        }
                    }

                    // Re-generate insight
                    Task {
                        await insightManager.handleJustCreatedMigraine(migraine)
                    }

                    // Recompute health and weather for the edited window
                    Task { @MainActor in
                        // Health snapshot for the migraine window
                        do {
                            let health = try await healthManager.fetchSnapshotForMigraine(start: startDate, end: endDate ?? Date())
                            migraineManager.update(migraine) { m in
                                m.health = health
                            }
                        } catch {
                            print("[Detail] Failed to fetch Health snapshot for edited migraine: \(error)")
                        }

                        // Weather: only attach if the edited start date is today; otherwise skip
                        let cal = Calendar.current
                        if cal.isDateInToday(startDate) {
                            await weatherManager.refresh()
                            if let wx = buildWeatherData(from: weatherManager, createdAt: startDate) {
                                migraineManager.update(migraine) { m in
                                    m.weather = wx
                                }
                            }
                        } else {
                            // Clear weather if previously set to avoid stale association
                            migraineManager.update(migraine) { m in
                                m.weather = nil
                            }
                            // Present a transient alert via print here; UI alert handled below
                            print("[Detail] Skipped attaching weather for past-dated migraine.")
                            pendingWeatherAlertMessage = "Weather isn't attached for past start dates."
                            showPendingWeatherAlert = true
                        }
                    }

                    showingModifySheet = false
                }
            )
        }
        .alert("Delete this migraine?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                migraineManager.delete(migraine)
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            // Initialize proposed end date when showing the view
            proposedEndDate = defaultEndDate
        }
    }
    
    private var headerDurationText: String {
        if let end = migraine.endDate {
            return formatDuration(from: migraine.startDate, to: end)
        } else {
            return formatLiveDuration(since: migraine.startDate)
        }
    }
    
    private var defaultEndDate: Date {
        let now = Date()
        return max(now, migraine.startDate.addingTimeInterval(60)) // ensure at least 1 min after start
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let interval = max(0, Int(end.timeIntervalSince(start)))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else {
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }
    
    private func formatLiveDuration(since start: Date) -> String {
        let interval = max(0, Int(Date().timeIntervalSince(start)))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else {
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }
    
    private func buildWeatherData(from wm: WeatherManager, createdAt date: Date) -> WeatherData? {
        let pressureHpa: Double? = {
            guard let p = wm.pressure else { return nil }
            return p.converted(to: .hectopascals).value
        }()
        let tempC: Double? = wm.temperature?.converted(to: .celsius).value
        let humidityPercent: Double? = wm.humidity.map { $0 * 100.0 }
        let condition: WeatherCondition? = wm.condition
        let location: String? = wm.locationString

        if let ph = pressureHpa, let tc = tempC, let hp = humidityPercent, let cond = condition {
            return WeatherData(
                barometricPressureHpa: ph,
                temperatureCelsius: tc,
                humidityPercent: hp,
                condition: cond,
                createdAt: date,
                locationDescription: location
            )
        } else if tempC != nil || pressureHpa != nil || humidityPercent != nil || condition != nil {
            return WeatherData(
                barometricPressureHpa: pressureHpa ?? 0,
                temperatureCelsius: tempC ?? 0,
                humidityPercent: humidityPercent ?? 0,
                condition: condition ?? .clear,
                createdAt: date,
                locationDescription: location
            )
        } else {
            return nil
        }
    }
}

#Preview("Migraine Detail – Sample") {
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
    
    // Provide defaults for AppStorage-backed preferences in preview
    UserDefaults.standard.register(defaults: [
        AppStorageKeys.useMetricUnits: false,
        AppStorageKeys.useDayMonthYearDates: false
    ])
    
    // Lightweight preview managers
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
    
    // Sample associated data
    let sampleWeather = WeatherData(
        barometricPressureHpa: 1008,
        temperatureCelsius: 22,
        humidityPercent: 65,
        condition: .partlyCloudy,
        createdAt: Date(),
        locationDescription: "Seattle, WA"
    )
    
    let sampleHealth = HealthData(
        waterLiters: 1.2,
        sleepHours: 6.5,
        energyKilocalories: 1800,
        caffeineMg: 120,
        stepCount: 5400,
        restingHeartRate: 58,
        activeHeartRate: 102,
        glucoseMgPerdL: 95,
        bloodOxygenPercent: 0.97,
        menstrualPhase: nil,
        migraine: nil,
        createdAt: Date()
    )
    
    let sampleMigraine = Migraine(
        pinned: false,
        startDate: Date().addingTimeInterval(-3*3600),
        endDate: Date().addingTimeInterval(-30*60),
        painLevel: 6,
        stressLevel: 5,
        note: "Flickering lights and skipped lunch.",
        insight: "Lower sleep and higher stress may have contributed. You could try keeping a more regular meal schedule and short screen breaks. This is general, non-medical guidance and not a diagnosis.",
        triggers: [],
        customTriggers: ["Bright lights", "Skipped lunch"],
        foodsEaten: ["Coffee", "Salad"],
        weather: sampleWeather,
        health: sampleHealth
    )
    
    container.mainContext.insert(sampleMigraine)
    
    return NavigationStack {
        MigraineDetailView(migraine: sampleMigraine)
    }
    .modelContainer(container)
    .environment(previewMigraineManager)
    .environment(previewInsightManager)
    .environment(previewWeatherManager)
    .environment(previewHealthManager)
    .environment(\.locale, .init(identifier: "en_US"))
}

