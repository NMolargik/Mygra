//
//  MigraineEntryView-ViewModel.swift
//  MygraFeatureMigraines
//
//  Form state and the save orchestration for a new migraine: validation, Health and
//  weather retrieval for the chosen window, staged intake writes, and assembling the
//  record. Pure form logic is host-testable; the managers are injected per call.
//

#if os(iOS)
import Foundation
import Observation
import MygraCore
import MygraServices
import os

extension MigraineEntryView {
    @MainActor
    @Observable
    final class ViewModel {
        // MARK: - Retrieval state
        var isPullingHealth = true
        var didPullHealth = false
        var healthError: (any Error)?

        var isPullingWeather = true
        var didPullWeather = false
        var weatherError: (any Error)?
        var showWeatherBackdateAlert = false

        var showHealthInfoAlert = false
        var healthInfoMessage = ""

        // MARK: - Form state
        var startDate = Date()
        var isOngoing = true
        var endDate = Date()
        var painLevel = 5
        var stressLevel = 5
        var selectedTriggers: Set<MigraineTrigger> = []
        var customTriggerInput = ""
        var customTriggers: [String] = []
        var foodsText = ""
        var noteText = ""
        var pinned = false
        var triggerSearchText = ""

        var showValidationAlert = false
        var validationMessage = ""

        // MARK: - Intake editing
        var isEditingIntake = false
        var additions = IntakeAdditions()

        // MARK: - Greeting
        var greeting = ""
        static let greetingOptions: [String] = [
            String(localized: "We’ve got you."),
            String(localized: "We’ll help you through this!"),
            String(localized: "Sorry you’re dealing with this..."),
            String(localized: "Let’s get you some relief."),
            String(localized: "Here to help."),
        ]

        static let weatherBackdateMessage = String(localized: "Weather isn't attached for past dates. We only attach current conditions for migraines started today.")

        init() {}

        // MARK: - Form mutations

        func toggleTrigger(_ trigger: MigraineTrigger) {
            if selectedTriggers.contains(trigger) {
                selectedTriggers.remove(trigger)
            } else {
                selectedTriggers.insert(trigger)
            }
        }

        /// Adds the typed custom trigger (title-cased, case-insensitively unique).
        func addCustomTrigger() {
            let trimmed = customTriggerInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            defer { customTriggerInput = "" }
            guard !customTriggers.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
            customTriggers.append(trimmed.capitalized)
        }

        func removeCustomTrigger(at index: Int) {
            guard customTriggers.indices.contains(index) else { return }
            customTriggers.remove(at: index)
        }

        /// Foods split on commas/newlines, trimmed, empties dropped.
        var parsedFoods: [String] {
            foodsText
                .components(separatedBy: CharacterSet(charactersIn: ",\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        var selectedTriggerCount: Int { selectedTriggers.count + customTriggers.count }

        @discardableResult
        func validateBeforeSave() -> Bool {
            if !isOngoing && endDate < startDate {
                validationMessage = String(localized: "End time must be after the start time.")
                showValidationAlert = true
                return false
            }
            if !(0...10).contains(painLevel) || !(0...10).contains(stressLevel) {
                validationMessage = String(localized: "Pain and stress levels must be between 0 and 10.")
                showValidationAlert = true
                return false
            }
            validationMessage = ""
            showValidationAlert = false
            return true
        }

        func resetGreeting() {
            greeting = Self.greetingOptions.randomElement() ?? ""
        }

        func clearStagedIntake() {
            additions = .none
        }

        // MARK: - Health status copy

        /// Which intake metrics read zero for the window, or empty when none.
        func zeroIntakeMetrics(in health: HealthData?) -> [String] {
            health?.zeroIntakeMetrics ?? []
        }

        func healthStatusText(latest: HealthData?) -> String {
            if isPullingHealth { return String(localized: "Pulling from Apple Health") }
            if healthError != nil { return String(localized: "Failed to pull from Apple Health") }
            if Calendar.current.isDateInToday(startDate) { return String(localized: "Pulled from Apple Health") }
            return String(localized: "Health data from \(startDate.formatted(date: .abbreviated, time: .omitted))")
        }

        func weatherStatusText() -> String {
            if isPullingWeather { return String(localized: "Pulling local weather") }
            if showWeatherBackdateAlert { return Self.weatherBackdateMessage }
            if didPullWeather {
                return weatherError == nil ? String(localized: "Pulled local weather") : String(localized: "Using recent weather")
            }
            return String(localized: "Failed to pull weather")
        }

        func presentHealthInfo(latest: HealthData?) {
            if healthError != nil {
                healthInfoMessage = String(localized: "We couldn't read your health data from Apple Health. This may happen if Mygra doesn't have permission to access Health data, or if there was a problem communicating with HealthKit.\n\nYou can still log this migraine, but health metrics won't be attached.")
            } else {
                let items = zeroIntakeMetrics(in: latest).formatted(.list(type: .and))
                healthInfoMessage = String(localized: "Your \(items) intake shows as zero for the selected time period. This could mean the data hasn't been logged in Apple Health yet.\n\nAccurate intake data helps identify migraine patterns. You can add today's consumption using the \"Add Consumption\" button below.")
            }
            showHealthInfoAlert = true
        }

        // MARK: - Retrieval

        #if canImport(HealthKit)
        func startHealthFetch(using healthManager: HealthManager) async {
            isPullingHealth = true
            didPullHealth = false
            healthError = nil

            await healthManager.refreshLatest(forMigraineStart: startDate)

            if let error = healthManager.lastError {
                healthError = error
                didPullHealth = false
            } else {
                didPullHealth = healthManager.latestData != nil
            }
            isPullingHealth = false
        }
        #endif

        func startWeatherFetch(using weatherManager: WeatherManager) async {
            isPullingWeather = true
            didPullWeather = false
            weatherError = nil

            // Weather is only attached for migraines that started today.
            guard Calendar.current.isDateInToday(startDate) else {
                isPullingWeather = false
                showWeatherBackdateAlert = true
                return
            }
            showWeatherBackdateAlert = false

            await weatherManager.refresh()
            didPullWeather = weatherManager.hasReading
            weatherError = weatherManager.error
            isPullingWeather = false
        }

        // MARK: - Save

        /// Writes staged intake to Health, snapshots Health and weather for the window,
        /// and assembles the record. Never blocks on Health/weather failures.
        #if canImport(HealthKit)
        func makeMigraine(using healthManager: HealthManager, weatherManager: WeatherManager) async -> Migraine {
            if !additions.isEmpty {
                do {
                    try await healthManager.save(additions, on: min(startDate, Date()))
                    clearStagedIntake()
                } catch {
                    Log.app.error("Failed to save staged intake to HealthKit during migraine submit: \(error.localizedDescription)")
                }
            }

            var health: HealthData?
            do {
                try? await Task.sleep(for: .milliseconds(200))
                health = try await healthManager.fetchSnapshot(forMigraineStart: startDate)
            } catch {
                Log.app.error("Failed to fetch Health snapshot for migraine window: \(error.localizedDescription)")
            }

            let weather = await currentWeatherData(using: weatherManager)
            return buildMigraine(health: health, weather: weather)
        }
        #endif

        /// The weather snapshot for a same-day start, or nil (and the backdate note) otherwise.
        func currentWeatherData(using weatherManager: WeatherManager) async -> WeatherData? {
            guard Calendar.current.isDateInToday(startDate) else {
                showWeatherBackdateAlert = true
                return nil
            }
            await weatherManager.refresh()
            return weatherManager.makeWeatherData(createdAt: startDate)
        }

        /// Assembles the record from the form (pure; health/weather are attached as given).
        func buildMigraine(health: HealthData?, weather: WeatherData?) -> Migraine {
            let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            return Migraine(
                pinned: pinned,
                startDate: startDate,
                endDate: isOngoing ? nil : endDate,
                painLevel: painLevel,
                stressLevel: stressLevel,
                note: note.isEmpty ? nil : noteText,
                insight: nil,
                triggers: Array(selectedTriggers),
                customTriggers: customTriggers,
                foodsEaten: parsedFoods,
                weather: weather,
                health: health
            )
        }
    }
}
#endif
