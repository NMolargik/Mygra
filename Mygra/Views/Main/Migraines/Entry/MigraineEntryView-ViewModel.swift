//
//  MigraineEntryView-ViewModel.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import SwiftUI
import WeatherKit

extension MigraineEntryView {
    @MainActor
    @Observable
    class ViewModel {
        // Local state to drive capsule UI
        var isPullingHealth = true
        var didPullHealth = false
        var healthError: Error?

        var isPullingWeather = true
        var didPullWeather = false
        var weatherError: Error?

        // Weather backdate alert state
        var showWeatherBackdateAlert: Bool = false
        var weatherBackdateMessage: String = ""

        // Entry form state
        var startDate: Date = Date()
        var isOngoing: Bool = true
        var endDate: Date = Date()
        var painLevel: Int = 5
        var stressLevel: Int = 5
        var selectedTriggers: Set<MigraineTrigger> = []
        // Custom triggers
        var customTriggerInput: String = ""
        var customTriggers: [String] = []
        var foodsText: String = ""
        var noteText: String = ""
        var pinned: Bool = false

        // UI helpers
        var triggerSearchText: String = ""
        var showValidationAlert: Bool = false
        var validationMessage: String = ""

        // Intake editing state (moved from @State in the view)
        var isEditingHealthValues: Bool = false
        var isSavingHealthEdits: Bool = false
        var healthEditErrorMessage: String?
        var addWater: Double = 0.0
        var addFood: Double = 0.0
        var addCaffeine: Double = 0.0
        var addSleepHours: Double = 0.0
        var allAddsAreZero: Bool { addWater == 0 && addFood == 0 && addCaffeine == 0 && addSleepHours == 0 }

        // Dynamic empathetic/helpful greeting
        var greeting: String = ""
        let greetingOptions: [String] = [
            "We’ve got you.",
            "We’ll help you through this!",
            "Sorry you’re dealing with this...",
            "Let’s get you some relief.",
            "Here to help."
        ]

        // MARK: - Convenience mutations

        func setOngoing(_ ongoing: Bool) {
            isOngoing = ongoing
            if !ongoing {
                if endDate < startDate {
                    endDate = max(Date(), startDate)
                }
            }
        }

        func toggleTrigger(_ trigger: MigraineTrigger) {
            if selectedTriggers.contains(trigger) {
                selectedTriggers.remove(trigger)
            } else {
                selectedTriggers.insert(trigger)
            }
        }

        func addCustomTrigger() {
            let trimmed = customTriggerInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            // Prevent duplicates case-insensitively
            let exists = customTriggers.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
            guard !exists else {
                customTriggerInput = ""
                return
            }
            // Store in title case for display
            let display = trimmed.capitalized
            customTriggers.append(display)
            customTriggerInput = ""
        }

        func removeCustomTrigger(at index: Int) {
            guard index >= 0 && index < customTriggers.count else { return }
            customTriggers.remove(at: index)
        }

        func parseFoods() -> [String] {
            foodsText
                .components(separatedBy: CharacterSet(charactersIn: ",\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        @discardableResult
        func validateBeforeSave() -> Bool {
            if !isOngoing && endDate < startDate {
                validationMessage = "End time must be after the start time."
                showValidationAlert = true
                return false
            }
            if painLevel < 0 || painLevel > 10 || stressLevel < 0 || stressLevel > 10 {
                validationMessage = "Pain and stress levels must be between 0 and 10."
                showValidationAlert = true
                return false
            }
            validationMessage = ""
            showValidationAlert = false
            return true
        }

        func resetGreeting() {
            greeting = greetingOptions.randomElement() ?? ""
        }

        // MARK: - Formatting & Display

        func displayWater(_ liters: Double, useMetricUnits: Bool) -> String {
            if useMetricUnits {
                return String(format: "%.1f L water", liters)
            } else {
                let ounces = liters * 33.814
                return String(format: "%.0f fl oz water", ounces.rounded())
            }
        }

        func displayGlucose(mgPerdL: Double, useMetricUnits: Bool) -> String {
            if useMetricUnits {
                let mmol = mgPerdL / 18.0
                return String(format: "%.1f mmol/L glucose", mmol)
            } else {
                return String(format: "%.0f mg/dL glucose", mgPerdL.rounded())
            }
        }

        func displayMenstrualPhase(_ phase: MenstrualPhase) -> String {
            switch phase {
            case .menstrual: return "Menstrual phase"
            case .follicular: return "Follicular phase"
            case .ovulatory: return "Ovulatory phase"
            case .luteal: return "Luteal phase"
            }
        }

        func menstrualPhaseIcon(_ phase: MenstrualPhase) -> String {
            switch phase {
            case .menstrual: return "drop.circle.fill"
            case .follicular: return "leaf.fill"
            case .ovulatory: return "sparkles"
            case .luteal: return "circle.lefthalf.filled"
            }
        }

        func menstrualPhaseColor(_ phase: MenstrualPhase) -> Color {
            switch phase {
            case .menstrual: return .pink
            case .follicular: return .green
            case .ovulatory: return .yellow
            case .luteal: return .orange
            }
        }

        func displayTemperature(_ temp: Measurement<UnitTemperature>, useMetricUnits: Bool) -> String {
            let value: Double
            let unit: String
            if useMetricUnits {
                value = temp.converted(to: .celsius).value
                unit = "°C"
            } else {
                value = temp.converted(to: .fahrenheit).value
                unit = "°F"
            }
            return "\(Int(round(value))) \(unit)"
        }

        func displayPressure(_ pressure: Measurement<UnitPressure>, useMetricUnits: Bool) -> String {
            if useMetricUnits {
                let hpa = pressure.converted(to: .hectopascals).value
                return String(format: "%.0f hPa", hpa)
            } else {
                let inHg = pressure.converted(to: .inchesOfMercury).value
                return String(format: "%.2f inHg", inHg)
            }
        }

        // MARK: - Triggers

        func filteredTriggers(for group: MigraineTrigger.Group, search: String) -> [MigraineTrigger] {
            let all = MigraineTrigger.cases(for: group)
            let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return all }
            let lower = trimmed.lowercased()
            return all.filter { $0.displayName.lowercased().contains(lower) }
        }

        func waterRange(useMetricUnits: Bool) -> ClosedRange<Double> {
            useMetricUnits ? 0...2.5 : 0...(2.5 * 33.814 / 33.814)
        }

        func waterStep(useMetricUnits: Bool) -> Double {
            return useMetricUnits ? 0.1 : (8.0 / 33.814)
        }

        func waterDisplay(_ value: Double, useMetricUnits: Bool) -> String {
            if useMetricUnits {
                return String(format: "+%.1f L", value)
            } else {
                return String(format: "+%.0f fl oz", value)
            }
        }

        func snap(_ value: Double, toStep step: Double, in range: ClosedRange<Double>) -> Double {
            guard step > 0 else { return min(max(value, range.lowerBound), range.upperBound) }
            let snapped = (value / step).rounded() * step
            return min(max(snapped, range.lowerBound), range.upperBound)
        }

        // MARK: - Experience color

        func gradientColor(for value: Int) -> Color {
            let v = max(0, min(10, value))
            if v <= 5 {
                let t = Double(v) / 5.0
                return Color(red: t, green: 1.0, blue: 0.0)
            } else {
                let t = Double(v - 5) / 5.0
                return Color(red: 1.0, green: 1.0 - t, blue: 0.0)
            }
        }
        
        // MARK: - Editor & fetch orchestration moved from View
        func toggleHealthEditor() {
            if !isEditingHealthValues {
                addWater = 0
                addFood = 0
                addCaffeine = 0
                addSleepHours = 0
                healthEditErrorMessage = nil
            }
            isEditingHealthValues.toggle()
        }

        @MainActor
        func saveHealthEdits(using healthManager: HealthManager, useMetricUnits: Bool) async {
            guard let current = healthManager.latestData else { return }
            isSavingHealthEdits = true
            defer { isSavingHealthEdits = false }

            do {
                // Water
                if addWater > 0 {
                    // addWater is already stored in liters; round to nearest milliliter for HealthKit precision
                    let liters = (addWater * 1000).rounded() / 1000
                    try await healthManager.saveWater(liters: liters)
                    current.waterLiters = (current.waterLiters ?? 0) + liters
                }
                // Calories
                if addFood > 0 {
                    try await healthManager.saveEnergy(kcal: addFood)
                    current.energyKilocalories = (current.energyKilocalories ?? 0) + addFood
                }
                // Caffeine
                if addCaffeine > 0 {
                    try await healthManager.saveCaffeine(mg: addCaffeine)
                    current.caffeineMg = (current.caffeineMg ?? 0) + addCaffeine
                }
                // Sleep
                if addSleepHours > 0 {
                    let end = Date()
                    let start = end.addingTimeInterval(-addSleepHours * 3600.0)
                    try await healthManager.saveSleep(from: start, to: end)
                    current.sleepHours = (current.sleepHours ?? 0) + addSleepHours
                }

                // Refresh snapshot to reconcile with HealthKit aggregates for the selected migraine window
                await healthManager.refreshLatestForMigraine(start: startDate, end: isOngoing ? nil : endDate)

                healthEditErrorMessage = nil
                isEditingHealthValues = false
                Haptics.success()
            } catch {
                healthEditErrorMessage = "Failed to save to Apple Health: \(error.localizedDescription)"
                Haptics.error()
            }
        }

        @MainActor
        func startHealthFetch(using healthManager: HealthManager) async {
            isPullingHealth = true
            didPullHealth = false
            healthError = nil

            // Use the selected start/end to fetch a migraine-window snapshot
            await healthManager.refreshLatestForMigraine(start: startDate, end: isOngoing ? nil : endDate)

            // Reflect results
            if let error = healthManager.lastError {
                healthError = error
                didPullHealth = false
            } else {
                didPullHealth = (healthManager.latestData != nil)
            }
            isPullingHealth = false
        }

        @MainActor
        func startWeatherFetch(using weatherManager: WeatherManager) async {
            isPullingWeather = true
            didPullWeather = false
            weatherError = nil

            // If the selected start date is not today, skip weather and alert the user.
            let cal = Calendar.current
            if !cal.isDateInToday(startDate) {
                isPullingWeather = false
                didPullWeather = false
                weatherError = nil
                showWeatherBackdateAlert = true
                weatherBackdateMessage = "Weather isn't attached for past dates. We only attach current conditions for migraines started today."
                return
            }

            await weatherManager.refresh()

            // Consider it "pulled" if we have at least one of the core readings, even if refresh errored.
            let hasAny = weatherManager.temperature != nil ||
                         weatherManager.pressure != nil ||
                         weatherManager.humidity != nil ||
                         weatherManager.condition != nil

            if let error = weatherManager.error {
                weatherError = error
                didPullWeather = hasAny
            } else {
                didPullWeather = hasAny
            }
            isPullingWeather = false
        }

        func buildWeatherData(from weatherManager: WeatherManager, for date: Date) -> WeatherData? {
            let pressureHpa: Double? = {
                guard let p = weatherManager.pressure else { return nil }
                let hPa = p.converted(to: .hectopascals).value
                return hPa
            }()
            let tempC: Double? = weatherManager.temperature?.converted(to: .celsius).value
            let humidityPercent: Double? = weatherManager.humidity.map { $0 * 100.0 }
            let condition: WeatherCondition? = weatherManager.condition
            let location: String? = weatherManager.locationString

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

        @MainActor
        func createMigraine(using healthManager: HealthManager, weatherManager: WeatherManager, useMetricUnits: Bool) async -> Migraine {
            // Attempt to fetch a Health snapshot for the migraine window
            var healthModel: HealthData? = nil
            do {
                try? await Task.sleep(nanoseconds: 200_000_000)
                let snapshot = try await healthManager.fetchSnapshotForMigraine(start: startDate, end: isOngoing ? nil : endDate)
                healthModel = snapshot
            } catch {
                // proceed without health
                print("Failed to fetch Health snapshot for migraine window: \(error)")
            }

            // Ensure we have a recent weather reading; then build a WeatherData using the migraine's start date
            let cal = Calendar.current
            let weatherModel: WeatherData?
            if cal.isDateInToday(startDate) {
                await weatherManager.refresh()
                weatherModel = buildWeatherData(from: weatherManager, for: startDate)
            } else {
                weatherModel = nil
                showWeatherBackdateAlert = true
                if weatherBackdateMessage.isEmpty {
                    weatherBackdateMessage = "Weather isn't attached for past dates. We only attach current conditions for migraines started today."
                }
            }

            // Foods parsing
            let foods: [String] = parseFoods()

            return Migraine(
                pinned: pinned,
                startDate: startDate,
                endDate: isOngoing ? nil : endDate,
                painLevel: painLevel,
                stressLevel: stressLevel,
                note: noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : noteText,
                insight: nil,
                triggers: Array(selectedTriggers),
                customTriggers: customTriggers,
                foodsEaten: foods,
                weather: weatherModel,
                health: healthModel
            )
        }
    }
}

