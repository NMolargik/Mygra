//
//  InsightManager.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import Foundation
import Observation
import WeatherKit

@Observable
@MainActor
final class InsightManager {

    // MARK: - Dependencies
    private let userManager: UserManager
    private let migraineManager: MigraineManager
    private let weatherManager: WeatherManager
    private let healthManager: HealthManager

    // MARK: - Public state
    private(set) var insights: [Insight] = []
    private(set) var isRefreshing: Bool = false
    private(set) var lastRefreshed: Date?
    private(set) var errors: [Error] = []

    // Cache of generated guidance per migraine
    private(set) var generatedGuidance: [UUID: String] = [:]
    private(set) var isGeneratingGuidance: Bool = false

    // MARK: - Init
    init(
        userManager: UserManager,
        migraineManager: MigraineManager,
        weatherManager: WeatherManager,
        healthManager: HealthManager
    ) {
        self.userManager = userManager
        self.migraineManager = migraineManager
        self.weatherManager = weatherManager
        self.healthManager = healthManager
    }

    // MARK: - Refresh orchestration
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errors.removeAll()

        do {
            let all = try await generateAll()
            insights = all.sorted(by: Insight.sorter)
            lastRefreshed = Date()
        } catch {
            errors.append(error)
        }

        isRefreshing = false
    }

    private func generateAll() async throws -> [Insight] {
        async let trends = generateMigraineTrends()
        async let triggers = generateTriggerInsights()
        async let foods = generateFoodInsights()
        async let intake = generateIntakeInsights()
        async let sleep = generateSleepInsights()
        async let weather = generateWeatherInsights()

        var all: [Insight] = []
        do { all += try await trends } catch { errors.append(error) }
        do { all += try await triggers } catch { errors.append(error) }
        do { all += try await foods } catch { errors.append(error) }
        do { all += try await intake } catch { errors.append(error) }
        do { all += try await sleep } catch { errors.append(error) }
        do { all += try await weather } catch { errors.append(error) }

        // De-duplicate
        var seen = Set<Insight.DedupeKey>()
        all = all.filter { seen.insert($0.dedupeKey).inserted }

        return all
    }

    // MARK: - Category generators

    // Trends: frequency, severity, duration (simple rolling 14-day comparison)
    private func generateMigraineTrends() async throws -> [Insight] {
        let items = migraineManager.migraines
        guard !items.isEmpty else { return [] }

        var results: [Insight] = []

        let now = Date()
        let cal = Calendar.current
        guard let start14 = cal.date(byAdding: .day, value: -14, to: now),
              let start28 = cal.date(byAdding: .day, value: -28, to: now) else { return [] }

        let recent = items.filter { $0.startDate >= start14 && $0.startDate <= now }
        let prior = items.filter { $0.startDate >= start28 && $0.startDate < start14 }

        // Frequency
        let freqRecent = recent.count
        let freqPrior = prior.count
        if freqRecent + freqPrior > 0, freqRecent != freqPrior {
            let delta = freqRecent - freqPrior
            let direction = delta > 0 ? "increased" : "decreased"
            let pct: Int = {
                if freqPrior == 0 { return 100 }
                let change = Double(abs(delta)) / Double(max(1, freqPrior))
                return Int(round(change * 100))
            }()
            results.append(
                Insight(
                    category: .trendFrequency,
                    title: "Migraine frequency \(direction)",
                    message: "Last 2 weeks: \(freqRecent) vs prior 2 weeks: \(freqPrior) (\(pct)% \(direction)).",
                    priority: delta > 0 ? .high : .medium,
                    tags: ["recent": freqRecent, "prior": freqPrior, "percent": pct]
                )
            )
        }

        // Severity (average painLevel)
        if let sr = averageSeverity(recent), let sp = averageSeverity(prior), abs(sr - sp) >= 0.5 {
            let direction = sr > sp ? "higher" : "lower"
            results.append(
                Insight(
                    category: .trendSeverity,
                    title: "Severity trending \(direction)",
                    message: String(format: "Avg severity last 2 weeks: %.1f vs prior: %.1f.", sr, sp),
                    priority: sr > sp ? .medium : .low,
                    tags: ["recent": sr, "prior": sp]
                )
            )
        }

        // Duration (average hours, only for completed migraines)
        if let dr = averageDurationHours(recent), let dp = averageDurationHours(prior), abs(dr - dp) >= 0.25 {
            let direction = dr > dp ? "longer" : "shorter"
            results.append(
                Insight(
                    category: .trendDuration,
                    title: "Migraine duration \(direction)",
                    message: String(format: "Avg duration last 2 weeks: %.2f h vs prior: %.2f h.", dr, dp),
                    priority: dr > dp ? .medium : .low,
                    tags: ["recent": dr, "prior": dp]
                )
            )
        }

        return results
    }

    private func averageSeverity(_ items: [Migraine]) -> Double? {
        guard !items.isEmpty else { return nil }
        let total = items.reduce(0) { $0 + $1.painLevel }
        return Double(total) / Double(items.count)
    }

    private func averageDurationHours(_ items: [Migraine]) -> Double? {
        let durations = items.compactMap { m -> Double? in
            guard let end = m.endDate else { return nil }
            let seconds = end.timeIntervalSince(m.startDate)
            return max(0, seconds) / 3600.0
        }
        guard !durations.isEmpty else { return nil }
        let sum = durations.reduce(0, +)
        return sum / Double(durations.count)
    }

    // Triggers: prevalence across migraines
    private func generateTriggerInsights() async throws -> [Insight] {
        let items = migraineManager.migraines
        guard !items.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        for m in items {
            for t in Set(m.triggers) {
                counts[t.displayName, default: 0] += 1
            }
        }
        guard !counts.isEmpty else { return [] }
        let total = items.count
        let top = counts.sorted { $0.value > $1.value }.prefix(5)

        return top.map { (name, count) in
            let pct = Double(count) / Double(total)
            return Insight(
                category: .triggers,
                title: "Common trigger: \(name)",
                message: String(format: "%.0f%% of migraines included %@", pct * 100.0, name),
                priority: pct >= 0.4 ? .high : (pct >= 0.25 ? .medium : .low),
                tags: ["count": count, "percent": pct]
            )
        }
    }

    // Foods: prevalence from foodsEaten
    private func generateFoodInsights() async throws -> [Insight] {
        let items = migraineManager.migraines
        guard !items.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        for m in items {
            let foods = m.foodsEaten
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            for f in Set(foods) {
                counts[f, default: 0] += 1
            }
        }
        guard !counts.isEmpty else { return [] }
        let total = items.count
        let top = counts.sorted { $0.value > $1.value }.prefix(5)

        return top.map { (name, count) in
            let pct = Double(count) / Double(total)
            return Insight(
                category: .foods,
                title: "Potential food trigger: \(name.capitalized)",
                message: String(format: "Appears in %.0f%% of migraines you logged.", pct * 100.0),
                priority: pct >= 0.35 ? .high : (pct >= 0.2 ? .medium : .low),
                tags: ["count": count, "percent": pct, "food": name]
            )
        }
    }

    // Intake gaps: hydration, sleep, calories on migraine days (from attached HealthData)
    private func generateIntakeInsights() async throws -> [Insight] {
        let items = migraineManager.migraines
        guard !items.isEmpty else { return [] }

        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now.addingTimeInterval(-14 * 24 * 3600)
        let window = items.filter { $0.startDate >= start }
        guard !window.isEmpty else { return [] }

        var results: [Insight] = []

        let hydration = window.compactMap { $0.health?.waterLiters }
        if !hydration.isEmpty {
            let avg = hydration.reduce(0, +) / Double(hydration.count)
            if avg < 1.2 {
                results.append(
                    Insight(
                        category: .intakeHydration,
                        title: "Low hydration on migraine days",
                        message: String(format: "Average water intake: %.1f L on migraine days.", avg),
                        priority: .high,
                        tags: ["avgLiters": avg]
                    )
                )
            }
        }

        let sleep = window.compactMap { $0.health?.sleepHours }
        if !sleep.isEmpty {
            let avg = sleep.reduce(0, +) / Double(sleep.count)
            if avg < 6.5 {
                results.append(
                    Insight(
                        category: .intakeSleep,
                        title: "Short sleep before migraines",
                        message: String(format: "Average sleep: %.1f h on migraine days.", avg),
                        priority: .medium,
                        tags: ["avgSleep": avg]
                    )
                )
            }
        }

        let calories = window.compactMap { $0.health?.energyKilocalories }
        if !calories.isEmpty {
            let avg = calories.reduce(0, +) / Double(calories.count)
            if avg < 1200 {
                results.append(
                    Insight(
                        category: .intakeNutrition,
                        title: "Low energy intake on migraine days",
                        message: String(format: "Average energy consumed: %.0f kcal on migraine days.", avg),
                        priority: .medium,
                        tags: ["avgKcal": avg]
                    )
                )
            }
        }

        return results
    }

    // Sleep association: compare avg pain for <7h vs ≥7h sleep
    private func generateSleepInsights() async throws -> [Insight] {
        let items = migraineManager.migraines
        guard items.count >= 5 else { return [] }

        let pairs: [(sleep: Double, pain: Int)] = items.compactMap { m in
            guard let s = m.health?.sleepHours else { return nil }
            return (sleep: s, pain: m.painLevel)
        }
        guard pairs.count >= 5 else { return [] }

        let low = pairs.filter { $0.sleep < 7.0 }
        let high = pairs.filter { $0.sleep >= 7.0 }
        guard !low.isEmpty, !high.isEmpty else { return [] }

        let lowAvg = Double(low.reduce(0) { $0 + $1.pain }) / Double(low.count)
        let highAvg = Double(high.reduce(0) { $0 + $1.pain }) / Double(high.count)

        if lowAvg - highAvg >= 1.0 {
            return [
                Insight(
                    category: .sleepAssociation,
                    title: "Lower sleep, higher pain",
                    message: String(format: "Avg pain with <7h sleep: %.1f vs ≥7h: %.1f.", lowAvg, highAvg),
                    priority: .medium,
                    tags: ["lowSleepAvgPain": lowAvg, "highSleepAvgPain": highAvg]
                )
            ]
        }
        return []
    }

    // Weather association: use WeatherData attached to migraines
    private func generateWeatherInsights() async throws -> [Insight] {
        let items = migraineManager.migraines
        guard items.count >= 5 else { return [] }

        let withWeather = items.compactMap { m -> (pressure: Double, tempC: Double, humidity: Double, pain: Int)? in
            guard let wx = m.weather else { return nil }
            return (wx.barometricPressureHpa, wx.temperatureCelsius, wx.humidityPercent, m.painLevel)
        }
        guard withWeather.count >= 5 else { return [] }

        var results: [Insight] = []

        // Low vs high pressure pain averages
        let lowP = withWeather.filter { $0.pressure < 1010 }
        let highP = withWeather.filter { $0.pressure >= 1010 }
        if !lowP.isEmpty, !highP.isEmpty {
            let lowAvg = Double(lowP.reduce(0) { $0 + $1.pain }) / Double(lowP.count)
            let highAvg = Double(highP.reduce(0) { $0 + $1.pain }) / Double(highP.count)
            if lowAvg - highAvg >= 1.0 {
                results.append(
                    Insight(
                        category: .weatherAssociation,
                        title: "Lower pressure linked to higher pain",
                        message: String(format: "Avg pain at <1010 hPa: %.1f vs ≥1010 hPa: %.1f.", lowAvg, highAvg),
                        priority: .medium,
                        tags: ["lowPressureAvgPain": lowAvg, "highPressureAvgPain": highAvg]
                    )
                )
            }
        }

        // Humidity ≥70% vs <70%
        let highH = withWeather.filter { $0.humidity >= 70.0 }
        let lowH = withWeather.filter { $0.humidity < 70.0 }
        if !highH.isEmpty, !lowH.isEmpty {
            let highAvg = Double(highH.reduce(0) { $0 + $1.pain }) / Double(highH.count)
            let lowAvg = Double(lowH.reduce(0) { $0 + $1.pain }) / Double(lowH.count)
            if highAvg - lowAvg >= 1.0 {
                results.append(
                    Insight(
                        category: .weatherAssociation,
                        title: "High humidity linked to higher pain",
                        message: String(format: "Avg pain at ≥70%% humidity: %.1f vs <70%%: %.1f.", highAvg, lowAvg),
                        priority: .low,
                        tags: ["highHumidityAvgPain": highAvg, "lowHumidityAvgPain": lowAvg]
                    )
                )
            }
        }

        // Temperature extremes simple notes
        let cold = withWeather.filter { $0.tempC <= 5.0 }
        if !cold.isEmpty {
            let avg = Double(cold.reduce(0) { $0 + $1.pain }) / Double(cold.count)
            results.append(
                Insight(
                    category: .weatherAssociation,
                    title: "Cold conditions during migraines",
                    message: String(format: "Average pain at ≤5°C: %.1f.", avg),
                    priority: .low,
                    tags: ["avgPainCold": avg]
                )
            )
        }
        let hot = withWeather.filter { $0.tempC >= 28.0 }
        if !hot.isEmpty {
            let avg = Double(hot.reduce(0) { $0 + $1.pain }) / Double(hot.count)
            results.append(
                Insight(
                    category: .weatherAssociation,
                    title: "Hot conditions during migraines",
                    message: String(format: "Average pain at ≥28°C: %.1f.", avg),
                    priority: .low,
                    tags: ["avgPainHot": avg]
                )
            )
        }

        return results
    }

    // MARK: - Generative guidance (placeholder for Foundation Models Framework)
    func generateGuidance(for migraine: Migraine) async {
        guard generatedGuidance[migraine.id] == nil else { return }
        isGeneratingGuidance = true
        defer { isGeneratingGuidance = false }

        guard FeatureFlags.foundationModelsAvailable else { return }

        do {
            let context = buildGuidanceContext(migraine: migraine)
            let text = try await GenerativeTextEngine.shared.generateAdvice(context: context)
            generatedGuidance[migraine.id] = text
        } catch {
            errors.append(error)
        }
    }

    private func buildGuidanceContext(migraine: Migraine) -> String {
        var parts: [String] = []
        parts.append("Start: \(migraine.startDate.description)")
        if let end = migraine.endDate { parts.append("End: \(end.description)") }
        parts.append("Pain: \(migraine.painLevel)")
        parts.append("Stress: \(migraine.stressLevel)")
        if !migraine.triggers.isEmpty {
            parts.append("Triggers: \(migraine.triggers.map { $0.displayName }.joined(separator: ", "))")
        }
        if !migraine.foodsEaten.isEmpty {
            parts.append("Foods: \(migraine.foodsEaten.joined(separator: ", "))")
        }
        if let wx = migraine.weather {
            parts.append(String(format: "Weather: %.0f hPa, %.0f%% humidity, %.1f°C, %@", wx.barometricPressureHpa, wx.humidityPercent, wx.temperatureCelsius, wx.condition.description))
        }
        if let h = migraine.health {
            var bits: [String] = []
            if let w = h.waterLiters { bits.append(String(format: "%.1f L water", w)) }
            if let s = h.sleepHours { bits.append(String(format: "%.1f h sleep", s)) }
            if let e = h.energyKilocalories { bits.append(String(format: "%.0f cal", e)) }
            if let c = h.caffeineMg { bits.append(String(format: "%.0f mg caffeine", c)) }
            if !bits.isEmpty { parts.append("Health: " + bits.joined(separator: ", ")) }
        }
        if let note = migraine.note, !note.isEmpty {
            parts.append("Notes: \(note)")
        }
        if let user = userManager.currentUser {
            parts.append("User: \(user.name)")
            parts.append("Avg sleep goal: \(String(format: "%.1f", user.averageSleepHours)) h")
            parts.append("Avg caffeine: \(Int(user.averageCaffeineMg)) mg")
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Insight model
struct Insight: Identifiable, Hashable {
    enum Category: String, Hashable {
        case trendFrequency
        case trendSeverity
        case trendDuration
        case triggers
        case foods
        case intakeHydration
        case intakeSleep
        case intakeNutrition
        case sleepAssociation
        case weatherAssociation
        case generative
    }

    enum Priority: Int, Comparable, Hashable {
        case low = 1
        case medium = 5
        case high = 9
        static func < (lhs: Priority, rhs: Priority) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id: UUID
    let category: Category
    let title: String
    let message: String
    let priority: Priority
    let generatedAt: Date
    let tags: [String: AnyHashable]

    init(
        id: UUID = UUID(),
        category: Category,
        title: String,
        message: String,
        priority: Priority,
        generatedAt: Date = Date(),
        tags: [String: AnyHashable] = [:]
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.message = message
        self.priority = priority
        self.generatedAt = generatedAt
        self.tags = tags
    }

    static func sorter(lhs: Insight, rhs: Insight) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        if lhs.category != rhs.category { return lhs.category.rawValue < rhs.category.rawValue }
        return lhs.generatedAt > rhs.generatedAt
    }

    struct DedupeKey: Hashable {
        let category: Category
        let title: String
        let message: String
    }

    var dedupeKey: DedupeKey { DedupeKey(category: category, title: title, message: message) }
}

// MARK: - Feature flag + generative engine placeholders
enum FeatureFlags {
    static var foundationModelsAvailable: Bool { false }
}

actor GenerativeTextEngine {
    static let shared = GenerativeTextEngine()
    func generateAdvice(context: String) async throws -> String {
        // Replace with Apple Foundation Models Framework usage when integrated
        return "Personalized guidance based on your migraine, health, and profile."
    }
}
