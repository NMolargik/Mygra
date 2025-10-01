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

    // Apple Intelligence / Foundation Models orchestrator (availability-gated internally)
    let intelligenceManager: IntelligenceManager

    // MARK: - Public state
    private(set) var insights: [Insight] = []
    private(set) var isRefreshing: Bool = false
    private(set) var lastRefreshed: Date?
    private(set) var errors: [InsightError] = []

    // Cache of generated guidance per migraine
    private(set) var generatedGuidance: [UUID: String] = [:]
    // Cache AI explanations for QuickBits (by insight dedupeKey hash)
    private(set) var quickBitExplanations: [String: QuickBitExplanation] = [:]
    var isGeneratingGuidance: Bool = false
    var isGeneratingGuidanceFor: Migraine? = nil

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
        self.intelligenceManager = IntelligenceManager(userManager: userManager, migraineManager: migraineManager)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(migraineCreated(_:)),
            name: MigraineManager.migraineCreatedNotification,
            object: migraineManager
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: MigraineManager.migraineCreatedNotification,
            object: migraineManager
        )
    }

    @objc private func migraineCreated(_ note: Notification) {
        guard let m = note.userInfo?["migraine"] as? Migraine else { return }
        Task { await self.handleJustCreatedMigraine(m) }
    }

    func handleJustCreatedMigraine(_ migraine: Migraine) async {
        guard intelligenceManager.supportsAppleIntelligence else { return }
        if let existing = migraine.insight, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            migraine.insight = nil
        }
        await analyzeNewlyCreatedMigraine(migraine)
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
            errors.append(.refreshFailed(underlying: error))
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
        async let phases = generateMenstrualPhaseInsights()

        var all: [Insight] = []
        do { all += try await trends } catch { errors.append(.trendsFailed(underlying: error)) }
        do { all += try await triggers } catch { errors.append(.triggersFailed(underlying: error)) }
        do { all += try await foods } catch { errors.append(.foodsFailed(underlying: error)) }
        do { all += try await intake } catch { errors.append(.intakeFailed(underlying: error)) }
        do { all += try await sleep } catch { errors.append(.sleepFailed(underlying: error)) }
        do { all += try await weather } catch { errors.append(.weatherFailed(underlying: error)) }
        do { all += try await phases } catch { errors.append(.phasesFailed(underlying: error)) }

        // De-duplicate
        var seen = Set<DedupeKey>()
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

    // Triggers: prevalence across migraines (includes custom triggers)
    private func generateTriggerInsights() async throws -> [Insight] {
        let items = migraineManager.migraines
        guard !items.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        for m in items {
            // predefined
            for t in Set(m.triggers) {
                counts[t.displayName, default: 0] += 1
            }
            // custom (normalized to lowercase for grouping)
            for raw in Set(m.customTriggers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }) {
                counts[raw.capitalized, default: 0] += 1
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

    // Intake gaps and biometrics on migraine days (from attached HealthData)
    private func generateIntakeInsights() async throws -> [Insight] {
        let items = migraineManager.migraines
        guard !items.isEmpty else { return [] }

        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now.addingTimeInterval(-14 * 24 * 3600)
        let window = items.filter { $0.startDate >= start }
        guard !window.isEmpty else { return [] }

        var results: [Insight] = []

        // Hydration
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

        // Sleep
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

        // Calories
        let calories = window.compactMap { $0.health?.energyKilocalories }
        if !calories.isEmpty {
            let avg = calories.reduce(0, +) / Double(calories.count)
            if avg < 1200 {
                results.append(
                    Insight(
                        category: .intakeNutrition,
                        title: "Low energy intake on migraine days",
                        message: String(format: "Average energy consumed: %.0f cal on migraine days.", avg),
                        priority: .medium,
                        tags: ["avgKcal": avg]
                    )
                )
            }
        }

        // Blood glucose (mg/dL)
        let glucose = window.compactMap { $0.health?.glucoseMgPerdL }
        if !glucose.isEmpty {
            let avg = glucose.reduce(0, +) / Double(glucose.count)
            if avg >= 140 {
                results.append(
                    Insight(
                        category: .biometrics,
                        title: "Higher glucose on migraine days",
                        message: String(format: "Average glucose around migraines: %.0f mg/dL.", avg.rounded()),
                        priority: .low,
                        tags: ["avgGlucoseMgPerdL": avg]
                    )
                )
            } else if avg <= 70 {
                results.append(
                    Insight(
                        category: .biometrics,
                        title: "Lower glucose on migraine days",
                        message: String(format: "Average glucose around migraines: %.0f mg/dL.", avg.rounded()),
                        priority: .low,
                        tags: ["avgGlucoseMgPerdL": avg]
                    )
                )
            }
        }

        // Oxygen saturation (fraction 0.0–1.0)
        let spo2Fractions = window.compactMap { $0.health?.bloodOxygenPercent }
        if !spo2Fractions.isEmpty {
            let percents = spo2Fractions.map { $0 * 100.0 }
            let avg = percents.reduce(0, +) / Double(percents.count)
            if avg < 92.0 {
                results.append(
                    Insight(
                        category: .biometrics,
                        title: "Very low oxygen saturation on migraine days",
                        message: String(format: "Average SpO₂: %.1f%% around migraines.", avg),
                        priority: .high,
                        tags: ["avgSpO2Percent": avg]
                    )
                )
            } else if avg < 95.0 {
                results.append(
                    Insight(
                        category: .biometrics,
                        title: "Lower oxygen saturation on migraine days",
                        message: String(format: "Average SpO₂: %.1f%% around migraines.", avg),
                        priority: .medium,
                        tags: ["avgSpO2Percent": avg]
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

    // Menstrual phase association: which phase correlates with higher pain
    private func generateMenstrualPhaseInsights() async throws -> [Insight] {
        let items = migraineManager.migraines
        let withPhase = items.compactMap { m -> (phase: MenstrualPhase, pain: Int)? in
            guard let p = m.health?.menstrualPhase else { return nil }
            return (p, m.painLevel)
        }
        guard withPhase.count >= 5 else { return [] }

        var sums: [MenstrualPhase: Int] = [:]
        var counts: [MenstrualPhase: Int] = [:]
        for entry in withPhase {
            sums[entry.phase, default: 0] += entry.pain
            counts[entry.phase, default: 0] += 1
        }
        let avgs: [(MenstrualPhase, Double)] = counts.compactMap { phase, count in
            guard count > 0, let sum = sums[phase] else { return nil }
            return (phase, Double(sum) / Double(count))
        }
        guard avgs.count >= 2 else { return [] }

        let sorted = avgs.sorted { $0.1 > $1.1 }
        guard let top = sorted.first, let bottom = sorted.last else { return [] }

        let diff = top.1 - bottom.1
        guard diff >= 1.0 else { return [] }

        func phaseDisplay(_ p: MenstrualPhase) -> String {
            switch p {
            case .menstrual: return "Menstrual"
            case .follicular: return "Follicular"
            case .ovulatory: return "Ovulatory"
            case .luteal: return "Luteal"
            }
        }

        return [
            Insight(
                category: .biometrics,
                title: "Higher pain during \(phaseDisplay(top.0)) phase",
                message: String(format: "Avg pain in %@: %.1f vs %@: %.1f.", phaseDisplay(top.0), top.1, phaseDisplay(bottom.0), bottom.1),
                priority: .medium,
                tags: [
                    "topPhase": top.0.rawValue,
                    "topAvg": top.1,
                    "bottomPhase": bottom.0.rawValue,
                    "bottomAvg": bottom.1
                ]
            )
        ]
    }

    // MARK: - Intelligence

    func analyzeNewlyCreatedMigraine(_ migraine: Migraine) async {
        guard intelligenceManager.supportsAppleIntelligence else {
            errors.append(.intelligenceUnavailable)
            return
        }
        guard !isGeneratingGuidance else { return }
        isGeneratingGuidance = true
        isGeneratingGuidanceFor = migraine
        defer {
            isGeneratingGuidance = false
            isGeneratingGuidanceFor = nil
        }

        let user = userManager.currentUser
        do {
            if #available(iOS 26.0, *) {
                if let text = try await intelligenceManager.analyze(migraine: migraine, user: user) {
                    migraineManager.update(migraine) { m in
                        m.insight = text
                    }
                    generatedGuidance[migraine.id] = text
                    let card = Insight(
                        category: .generative,
                        title: "Migraine explanation",
                        message: text,
                        priority: .medium,
                        tags: ["migraineID": migraine.id]
                    )
                    insights.insert(card, at: 0)
                }
            } else {
                // Fallback on earlier versions
            }
        } catch {
            errors.append(.intelligenceAnalysisFailed(underlying: error))
        }
    }

    func startCounselorChat() async {
        guard intelligenceManager.supportsAppleIntelligence else { 
            errors.append(.intelligenceUnavailable)
            return 
        }
        let all = migraineManager.migraines
        let user = userManager.currentUser
        if #available(iOS 26.0, *) {
            await intelligenceManager.startChat(migraines: all, user: user)
        } else {
            // Fallback on earlier versions
        }
    }

    @available(iOS 26.0, *)
    func sendCounselorMessage(_ text: String) async -> String {
        guard intelligenceManager.supportsAppleIntelligence else {
            errors.append(.intelligenceUnavailable)
            return "This device does not support Apple Intelligence."
        }
        do {
            self.isGeneratingGuidance = true
            let reply = try await intelligenceManager.send(message: text)
            self.isGeneratingGuidance = false
            return reply
        } catch {
            self.isGeneratingGuidance = false
            errors.append(.chatSendFailed(underlying: error))
            return "Sorry, I ran into a problem."
        }
    }

    func resetCounselorChat() {
        intelligenceManager.resetChat()
    }

    // MARK: - QuickBit explanations
    @available(iOS 26.0, *)
    func explanation(for insight: Insight) async -> QuickBitExplanation? {
        guard intelligenceManager.supportsAppleIntelligence else { return nil }
        let key = insight.dedupeKey.key
        if let cached = quickBitExplanations[key] { return cached }
        do {
            let user = userManager.currentUser
            if let exp = try await intelligenceManager.explain(insight: insight, user: user) {
                quickBitExplanations[key] = exp
                return exp
            }
        } catch {
            errors.append(.intelligenceAnalysisFailed(underlying: error))
        }
        return nil
    }
}
