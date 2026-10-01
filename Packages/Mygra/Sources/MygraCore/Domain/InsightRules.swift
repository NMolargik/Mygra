//
//  InsightRules.swift
//  MygraCore
//
//  Pure, deterministic insight generation over migraine records. Every rule takes
//  explicit `now`/`calendar` parameters and touches no services, so each is unit-tested
//  in isolation on the host.
//

import Foundation

public enum InsightRules {

    /// Runs every rule and de-duplicates the combined results.
    public static func generateAll(
        from items: [Migraine],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Insight] {
        var all: [Insight] = []
        all += trends(items, now: now, calendar: calendar)
        all += triggers(items)
        all += foods(items)
        all += intake(items, now: now, calendar: calendar)
        all += sleep(items)
        all += weather(items)
        all += menstrualPhases(items)
        all += intensityPatterns(items)
        all += tags(items)
        return all.uniqued(by: \.dedupeKey)
    }

    // MARK: - Trends (rolling 14-day comparison)

    public static func trends(_ items: [Migraine], now: Date = Date(), calendar: Calendar = .current) -> [Insight] {
        guard !items.isEmpty,
              let start14 = calendar.date(byAdding: .day, value: -14, to: now),
              let start28 = calendar.date(byAdding: .day, value: -28, to: now) else { return [] }

        var results: [Insight] = []
        let recent = items.filter { $0.startDate >= start14 && $0.startDate <= now }
        let prior = items.filter { $0.startDate >= start28 && $0.startDate < start14 }

        // Frequency
        let freqRecent = recent.count
        let freqPrior = prior.count
        if freqRecent + freqPrior > 0, freqRecent != freqPrior {
            let delta = freqRecent - freqPrior
            let direction = delta > 0 ? String(localized: "increased") : String(localized: "decreased")
            let pct: Int = {
                if freqPrior == 0 { return 100 }
                let change = Double(abs(delta)) / Double(max(1, freqPrior))
                return Int(round(change * 100))
            }()
            results.append(
                Insight(
                    category: .trendFrequency,
                    title: String(localized: "Migraine frequency \(direction)"),
                    message: String(localized: "Last 2 weeks: \(freqRecent) vs prior 2 weeks: \(freqPrior) (\(pct)% \(direction))."),
                    priority: delta > 0 ? .high : .medium,
                    tags: ["recent": freqRecent, "prior": freqPrior, "percent": pct]
                )
            )
        }

        // Severity (average painLevel)
        if let sr = MigraineStatistics.averageSeverity(recent),
           let sp = MigraineStatistics.averageSeverity(prior),
           abs(sr - sp) >= 0.5 {
            let direction = sr > sp ? String(localized: "higher") : String(localized: "lower")
            results.append(
                Insight(
                    category: .trendSeverity,
                    title: String(localized: "Severity trending \(direction)"),
                    message: String(format: String(localized: "Avg severity last 2 weeks: %.1f vs prior: %.1f."), sr, sp),
                    priority: sr > sp ? .medium : .low,
                    tags: ["recent": sr, "prior": sp]
                )
            )
        }

        // Duration (average hours, completed migraines only)
        if let dr = MigraineStatistics.averageDurationHours(recent),
           let dp = MigraineStatistics.averageDurationHours(prior),
           abs(dr - dp) >= 0.25 {
            let direction = dr > dp ? String(localized: "longer") : String(localized: "shorter")
            results.append(
                Insight(
                    category: .trendDuration,
                    title: String(localized: "Migraine duration \(direction)"),
                    message: String(format: String(localized: "Avg duration last 2 weeks: %.2f h vs prior: %.2f h."), dr, dp),
                    priority: dr > dp ? .medium : .low,
                    tags: ["recent": dr, "prior": dp]
                )
            )
        }

        return results
    }

    // MARK: - Trigger prevalence (canonical + custom)

    public static func triggers(_ items: [Migraine]) -> [Insight] {
        guard !items.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        for migraine in items {
            for trigger in Set(migraine.triggers) {
                counts[trigger.displayName, default: 0] += 1
            }
            let custom = migraine.customTriggers
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            for raw in Set(custom) {
                counts[raw.capitalized, default: 0] += 1
            }
        }
        guard !counts.isEmpty else { return [] }
        let total = items.count

        return counts.sorted { $0.value > $1.value }.prefix(5).map { name, count in
            let pct = Double(count) / Double(total)
            return Insight(
                category: .triggers,
                title: String(localized: "Common trigger: \(name)"),
                message: String(format: String(localized: "%.0f%% of migraines included %@"), pct * 100.0, name),
                priority: pct >= 0.4 ? .high : (pct >= 0.25 ? .medium : .low),
                tags: ["count": count, "percent": pct]
            )
        }
    }

    // MARK: - Food prevalence

    public static func foods(_ items: [Migraine]) -> [Insight] {
        guard !items.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        for migraine in items {
            let foods = migraine.foodsEaten
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            for food in Set(foods) {
                counts[food, default: 0] += 1
            }
        }
        guard !counts.isEmpty else { return [] }
        let total = items.count

        return counts.sorted { $0.value > $1.value }.prefix(5).map { name, count in
            let pct = Double(count) / Double(total)
            return Insight(
                category: .foods,
                title: String(localized: "Potential food trigger: \(name.capitalized)"),
                message: String(format: String(localized: "Appears in %.0f%% of migraines you logged."), pct * 100.0),
                priority: pct >= 0.35 ? .high : (pct >= 0.2 ? .medium : .low),
                tags: ["count": count, "percent": pct, "food": name]
            )
        }
    }

    // MARK: - Intake gaps and biometrics on migraine days

    public static func intake(_ items: [Migraine], now: Date = Date(), calendar: Calendar = .current) -> [Insight] {
        guard !items.isEmpty else { return [] }

        let start = calendar.date(byAdding: .day, value: -14, to: now) ?? now.addingTimeInterval(-14 * 24 * 3600)
        let window = items.filter { $0.startDate >= start }
        guard !window.isEmpty else { return [] }

        var results: [Insight] = []

        if let avg = average(window.compactMap { $0.health?.waterLiters }), avg < 1.2 {
            results.append(
                Insight(
                    category: .intakeHydration,
                    title: String(localized: "Low hydration on migraine days"),
                    message: String(format: String(localized: "Average water intake: %.1f L on migraine days."), avg),
                    priority: .high,
                    tags: ["avgLiters": avg]
                )
            )
        }

        if let avg = average(window.compactMap { $0.health?.sleepHours }), avg < 6.5 {
            results.append(
                Insight(
                    category: .intakeSleep,
                    title: String(localized: "Short sleep before migraines"),
                    message: String(format: String(localized: "Average sleep: %.1f h on migraine days."), avg),
                    priority: .medium,
                    tags: ["avgSleep": avg]
                )
            )
        }

        if let avg = average(window.compactMap { $0.health?.energyKilocalories }), avg < 1200 {
            results.append(
                Insight(
                    category: .intakeNutrition,
                    title: String(localized: "Low energy intake on migraine days"),
                    message: String(format: String(localized: "Average energy consumed: %.0f cal on migraine days."), avg),
                    priority: .medium,
                    tags: ["avgKcal": avg]
                )
            )
        }

        if let avg = average(window.compactMap { $0.health?.glucoseMgPerdL }) {
            if avg >= 140 {
                results.append(
                    Insight(
                        category: .biometrics,
                        title: String(localized: "Higher glucose on migraine days"),
                        message: String(format: String(localized: "Average glucose around migraines: %.0f mg/dL."), avg.rounded()),
                        priority: .low,
                        tags: ["avgGlucoseMgPerdL": avg]
                    )
                )
            } else if avg <= 70 {
                results.append(
                    Insight(
                        category: .biometrics,
                        title: String(localized: "Lower glucose on migraine days"),
                        message: String(format: String(localized: "Average glucose around migraines: %.0f mg/dL."), avg.rounded()),
                        priority: .low,
                        tags: ["avgGlucoseMgPerdL": avg]
                    )
                )
            }
        }

        if let avgFraction = average(window.compactMap { $0.health?.bloodOxygenPercent }) {
            let avg = avgFraction * 100.0
            if avg < 92.0 {
                results.append(
                    Insight(
                        category: .biometrics,
                        title: String(localized: "Very low oxygen saturation on migraine days"),
                        message: String(format: String(localized: "Average SpO₂: %.1f%% around migraines."), avg),
                        priority: .high,
                        tags: ["avgSpO2Percent": avg]
                    )
                )
            } else if avg < 95.0 {
                results.append(
                    Insight(
                        category: .biometrics,
                        title: String(localized: "Lower oxygen saturation on migraine days"),
                        message: String(format: String(localized: "Average SpO₂: %.1f%% around migraines."), avg),
                        priority: .medium,
                        tags: ["avgSpO2Percent": avg]
                    )
                )
            }
        }

        return results
    }

    // MARK: - Sleep association (<7h vs ≥7h)

    public static func sleep(_ items: [Migraine]) -> [Insight] {
        guard items.count >= 5 else { return [] }

        let pairs: [(sleep: Double, pain: Int)] = items.compactMap { migraine in
            guard let sleep = migraine.health?.sleepHours else { return nil }
            return (sleep: sleep, pain: migraine.painLevel)
        }
        guard pairs.count >= 5 else { return [] }

        let low = pairs.filter { $0.sleep < 7.0 }
        let high = pairs.filter { $0.sleep >= 7.0 }
        guard !low.isEmpty, !high.isEmpty else { return [] }

        let lowAvg = averagePain(low.map(\.pain))
        let highAvg = averagePain(high.map(\.pain))

        if lowAvg - highAvg >= 1.0 {
            return [
                Insight(
                    category: .sleepAssociation,
                    title: String(localized: "Lower sleep, higher pain"),
                    message: String(format: String(localized: "Avg pain with <7h sleep: %.1f vs ≥7h: %.1f."), lowAvg, highAvg),
                    priority: .medium,
                    tags: ["lowSleepAvgPain": lowAvg, "highSleepAvgPain": highAvg]
                )
            ]
        }
        return []
    }

    // MARK: - Weather association

    public static func weather(_ items: [Migraine]) -> [Insight] {
        guard items.count >= 5 else { return [] }

        let withWeather = items.compactMap { migraine -> (pressure: Double, tempC: Double, humidity: Double, pain: Int)? in
            guard let weather = migraine.weather else { return nil }
            return (weather.barometricPressureHpa, weather.temperatureCelsius, weather.humidityPercent, migraine.painLevel)
        }
        guard withWeather.count >= 5 else { return [] }

        var results: [Insight] = []

        let lowP = withWeather.filter { $0.pressure < 1010 }
        let highP = withWeather.filter { $0.pressure >= 1010 }
        if !lowP.isEmpty, !highP.isEmpty {
            let lowAvg = averagePain(lowP.map(\.pain))
            let highAvg = averagePain(highP.map(\.pain))
            if lowAvg - highAvg >= 1.0 {
                results.append(
                    Insight(
                        category: .weatherAssociation,
                        title: String(localized: "Lower pressure linked to higher pain"),
                        message: String(format: String(localized: "Avg pain at <1010 hPa: %.1f vs ≥1010 hPa: %.1f."), lowAvg, highAvg),
                        priority: .medium,
                        tags: ["lowPressureAvgPain": lowAvg, "highPressureAvgPain": highAvg]
                    )
                )
            }
        }

        let highH = withWeather.filter { $0.humidity >= 70.0 }
        let lowH = withWeather.filter { $0.humidity < 70.0 }
        if !highH.isEmpty, !lowH.isEmpty {
            let highAvg = averagePain(highH.map(\.pain))
            let lowAvg = averagePain(lowH.map(\.pain))
            if highAvg - lowAvg >= 1.0 {
                results.append(
                    Insight(
                        category: .weatherAssociation,
                        title: String(localized: "High humidity linked to higher pain"),
                        message: String(format: String(localized: "Avg pain at ≥70%% humidity: %.1f vs <70%%: %.1f."), highAvg, lowAvg),
                        priority: .low,
                        tags: ["highHumidityAvgPain": highAvg, "lowHumidityAvgPain": lowAvg]
                    )
                )
            }
        }

        let cold = withWeather.filter { $0.tempC <= 5.0 }
        if !cold.isEmpty {
            let avg = averagePain(cold.map(\.pain))
            results.append(
                Insight(
                    category: .weatherAssociation,
                    title: String(localized: "Cold conditions during migraines"),
                    message: String(format: String(localized: "Average pain at ≤5°C: %.1f."), avg),
                    priority: .low,
                    tags: ["avgPainCold": avg]
                )
            )
        }
        let hot = withWeather.filter { $0.tempC >= 28.0 }
        if !hot.isEmpty {
            let avg = averagePain(hot.map(\.pain))
            results.append(
                Insight(
                    category: .weatherAssociation,
                    title: String(localized: "Hot conditions during migraines"),
                    message: String(format: String(localized: "Average pain at ≥28°C: %.1f."), avg),
                    priority: .low,
                    tags: ["avgPainHot": avg]
                )
            )
        }

        return results
    }

    // MARK: - Menstrual phase association

    public static func menstrualPhases(_ items: [Migraine]) -> [Insight] {
        let withPhase = items.compactMap { migraine -> (phase: MenstrualPhase, pain: Int)? in
            guard let phase = migraine.health?.menstrualPhase else { return nil }
            return (phase, migraine.painLevel)
        }
        guard withPhase.count >= 5 else { return [] }

        var sums: [MenstrualPhase: Int] = [:]
        var counts: [MenstrualPhase: Int] = [:]
        for entry in withPhase {
            sums[entry.phase, default: 0] += entry.pain
            counts[entry.phase, default: 0] += 1
        }
        let averages: [(MenstrualPhase, Double)] = counts.compactMap { phase, count in
            guard count > 0, let sum = sums[phase] else { return nil }
            return (phase, Double(sum) / Double(count))
        }
        guard averages.count >= 2 else { return [] }

        let sorted = averages.sorted { $0.1 > $1.1 }
        guard let top = sorted.first, let bottom = sorted.last, top.1 - bottom.1 >= 1.0 else { return [] }

        return [
            Insight(
                category: .biometrics,
                title: String(localized: "Higher pain during \(top.0.displayName) phase"),
                message: String(format: String(localized: "Avg pain in %@: %.1f vs %@: %.1f."), top.0.displayName, top.1, bottom.0.displayName, bottom.1),
                priority: .medium,
                tags: [
                    "topPhase": top.0.rawValue,
                    "topAvg": top.1,
                    "bottomPhase": bottom.0.rawValue,
                    "bottomAvg": bottom.1,
                ]
            )
        ]
    }

    // MARK: - Intensity patterns (how pain/stress evolve during migraines)

    public static func intensityPatterns(_ items: [Migraine]) -> [Insight] {
        guard !items.isEmpty else { return [] }

        let migrainesWithSamples = items.filter { ($0.intensitySamples ?? []).count >= 2 }
        guard !migrainesWithSamples.isEmpty else { return [] }

        var results: [Insight] = []
        var increasingCount = 0
        var decreasingCount = 0
        var peakInFirstHalfCount = 0
        var peakInSecondHalfCount = 0
        var totalAnalyzed = 0
        var stressChanges: [Int] = []

        for migraine in migrainesWithSamples {
            let samples = migraine.sortedIntensitySamples
            guard let first = samples.first, let last = samples.last, samples.count >= 2 else { continue }

            totalAnalyzed += 1

            if last.painLevel > first.painLevel + 1 {
                increasingCount += 1
            } else if last.painLevel < first.painLevel - 1 {
                decreasingCount += 1
            }

            if let peakIndex = samples.indices.max(by: { samples[$0].painLevel < samples[$1].painLevel }) {
                if peakIndex < samples.count / 2 {
                    peakInFirstHalfCount += 1
                } else {
                    peakInSecondHalfCount += 1
                }
            }

            stressChanges.append(last.stressLevel - first.stressLevel)
        }

        guard totalAnalyzed >= 3 else { return results }

        let increasingPct = Double(increasingCount) / Double(totalAnalyzed)
        let decreasingPct = Double(decreasingCount) / Double(totalAnalyzed)

        if increasingPct >= 0.5 {
            results.append(
                Insight(
                    category: .intensityPattern,
                    title: String(localized: "Pain tends to build over time"),
                    message: String(format: String(localized: "%.0f%% of your migraines show increasing pain intensity."), increasingPct * 100),
                    priority: .medium,
                    tags: ["increasingPercent": increasingPct, "analyzed": totalAnalyzed]
                )
            )
        } else if decreasingPct >= 0.5 {
            results.append(
                Insight(
                    category: .intensityPattern,
                    title: String(localized: "Pain tends to ease over time"),
                    message: String(format: String(localized: "%.0f%% of your migraines show decreasing pain intensity."), decreasingPct * 100),
                    priority: .low,
                    tags: ["decreasingPercent": decreasingPct, "analyzed": totalAnalyzed]
                )
            )
        }

        let earlyPeakPct = Double(peakInFirstHalfCount) / Double(totalAnalyzed)
        let latePeakPct = Double(peakInSecondHalfCount) / Double(totalAnalyzed)

        if earlyPeakPct >= 0.6 {
            results.append(
                Insight(
                    category: .intensityPeakTiming,
                    title: String(localized: "Peak pain occurs early"),
                    message: String(format: String(localized: "%.0f%% of migraines reach peak intensity in the first half."), earlyPeakPct * 100),
                    priority: .medium,
                    tags: ["earlyPeakPercent": earlyPeakPct, "analyzed": totalAnalyzed]
                )
            )
        } else if latePeakPct >= 0.6 {
            results.append(
                Insight(
                    category: .intensityPeakTiming,
                    title: String(localized: "Peak pain occurs later"),
                    message: String(format: String(localized: "%.0f%% of migraines reach peak intensity in the second half."), latePeakPct * 100),
                    priority: .medium,
                    tags: ["latePeakPercent": latePeakPct, "analyzed": totalAnalyzed]
                )
            )
        }

        if !stressChanges.isEmpty {
            let avgStressChange = Double(stressChanges.reduce(0, +)) / Double(stressChanges.count)
            if avgStressChange >= 2.0 {
                results.append(
                    Insight(
                        category: .intensityPattern,
                        title: String(localized: "Stress increases during migraines"),
                        message: String(format: String(localized: "On average, stress increases by %.1f points during your migraines."), avgStressChange),
                        priority: .medium,
                        tags: ["avgStressChange": avgStressChange]
                    )
                )
            } else if avgStressChange <= -2.0 {
                results.append(
                    Insight(
                        category: .intensityPattern,
                        title: String(localized: "Stress decreases during migraines"),
                        message: String(format: String(localized: "On average, stress decreases by %.1f points during your migraines."), abs(avgStressChange)),
                        priority: .low,
                        tags: ["avgStressChange": avgStressChange]
                    )
                )
            }
        }

        return results
    }

    // MARK: - Tag insights (frequency + severity correlation)

    public static func tags(_ items: [Migraine]) -> [Insight] {
        guard !items.isEmpty else { return [] }

        let migrainesWithTags = items.filter { !($0.tags ?? []).isEmpty }
        guard !migrainesWithTags.isEmpty else { return [] }

        var results: [Insight] = []

        var tagCounts: [String: Int] = [:]
        var tagSeveritySum: [String: Int] = [:]
        var tagSeverityCount: [String: Int] = [:]

        for migraine in items {
            for tag in migraine.tags ?? [] {
                tagCounts[tag.name, default: 0] += 1
                tagSeveritySum[tag.name, default: 0] += migraine.painLevel
                tagSeverityCount[tag.name, default: 0] += 1
            }
        }

        guard !tagCounts.isEmpty else { return [] }

        let total = items.count
        let sortedByFrequency = tagCounts.sorted { $0.value > $1.value }

        if let topTag = sortedByFrequency.first, topTag.value >= 3 {
            let pct = Double(topTag.value) / Double(total) * 100
            results.append(
                Insight(
                    category: .tagFrequency,
                    title: String(localized: "Most common tag: \(topTag.key)"),
                    message: String(format: String(localized: "\"%@\" appears in %.0f%% of your migraines (%d total)."), topTag.key, pct, topTag.value),
                    priority: pct >= 40 ? .medium : .low,
                    tags: ["tag": topTag.key, "count": topTag.value, "percent": pct]
                )
            )
        }

        var tagAvgSeverity: [(name: String, avg: Double, count: Int)] = []
        for (name, sum) in tagSeveritySum {
            guard let count = tagSeverityCount[name], count >= 2 else { continue }
            tagAvgSeverity.append((name: name, avg: Double(sum) / Double(count), count: count))
        }

        let overallAvgSeverity = MigraineStatistics.averageSeverity(items) ?? 5.0
        let highSeverityTags = tagAvgSeverity.filter { $0.avg >= overallAvgSeverity + 1.5 }.sorted { $0.avg > $1.avg }

        if let highest = highSeverityTags.first {
            results.append(
                Insight(
                    category: .tagSeverityCorrelation,
                    title: String(localized: "\"\(highest.name)\" linked to higher pain"),
                    message: String(format: String(localized: "Migraines tagged \"%@\" average %.1f pain vs %.1f overall."), highest.name, highest.avg, overallAvgSeverity),
                    priority: .high,
                    tags: ["tag": highest.name, "tagAvg": highest.avg, "overallAvg": overallAvgSeverity]
                )
            )
        }

        let lowSeverityTags = tagAvgSeverity.filter { $0.avg <= overallAvgSeverity - 1.5 }.sorted { $0.avg < $1.avg }

        if let lowest = lowSeverityTags.first {
            results.append(
                Insight(
                    category: .tagSeverityCorrelation,
                    title: String(localized: "\"\(lowest.name)\" linked to lower pain"),
                    message: String(format: String(localized: "Migraines tagged \"%@\" average %.1f pain vs %.1f overall."), lowest.name, lowest.avg, overallAvgSeverity),
                    priority: .low,
                    tags: ["tag": lowest.name, "tagAvg": lowest.avg, "overallAvg": overallAvgSeverity]
                )
            )
        }

        var coOccurrences: [String: Int] = [:]
        for migraine in migrainesWithTags {
            let names = (migraine.tags ?? []).map(\.name).sorted()
            guard names.count >= 2 else { continue }
            for i in 0..<names.count {
                for j in (i + 1)..<names.count {
                    coOccurrences["\(names[i]) + \(names[j])", default: 0] += 1
                }
            }
        }

        if let topPair = coOccurrences.max(by: { $0.value < $1.value }), topPair.value >= 3 {
            results.append(
                Insight(
                    category: .tagFrequency,
                    title: String(localized: "Tags often appear together"),
                    message: String(localized: "\"\(topPair.key)\" occur together in \(topPair.value) migraines."),
                    priority: .low,
                    tags: ["pair": topPair.key, "count": topPair.value]
                )
            )
        }

        return results
    }

    // MARK: - Helpers

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func averagePain(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}
