//
//  InsightRules.swift
//  Mygra
//
//  Pure, deterministic insight generation over migraine records.
//  Extracted from InsightManager so every rule is unit-testable: all rules
//  take explicit `now`/`calendar` parameters and touch no managers.
//

import Foundation

enum InsightRules {

    /// Runs every rule and de-duplicates the combined results.
    static func generateAll(
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

        var seen = Set<DedupeKey>()
        return all.filter { seen.insert($0.dedupeKey).inserted }
    }

    // MARK: - Trends (rolling 14-day comparison)

    static func trends(_ items: [Migraine], now: Date = Date(), calendar: Calendar = .current) -> [Insight] {
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
        if let sr = MigraineStatistics.averageSeverity(recent),
           let sp = MigraineStatistics.averageSeverity(prior),
           abs(sr - sp) >= 0.5 {
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

        // Duration (average hours, completed migraines only)
        if let dr = MigraineStatistics.averageDurationHours(recent),
           let dp = MigraineStatistics.averageDurationHours(prior),
           abs(dr - dp) >= 0.25 {
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

    // MARK: - Trigger prevalence (canonical + custom)

    static func triggers(_ items: [Migraine]) -> [Insight] {
        guard !items.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        for m in items {
            for t in Set(m.triggers) {
                counts[t.displayName, default: 0] += 1
            }
            for raw in Set(m.customTriggers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }) {
                counts[raw.capitalized, default: 0] += 1
            }
        }
        guard !counts.isEmpty else { return [] }
        let total = items.count

        return counts.sorted { $0.value > $1.value }.prefix(5).map { (name, count) in
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

    // MARK: - Food prevalence

    static func foods(_ items: [Migraine]) -> [Insight] {
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

        return counts.sorted { $0.value > $1.value }.prefix(5).map { (name, count) in
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

    // MARK: - Intake gaps and biometrics on migraine days

    static func intake(_ items: [Migraine], now: Date = Date(), calendar: Calendar = .current) -> [Insight] {
        guard !items.isEmpty else { return [] }

        let start = calendar.date(byAdding: .day, value: -14, to: now) ?? now.addingTimeInterval(-14 * 24 * 3600)
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

    // MARK: - Sleep association (<7h vs ≥7h)

    static func sleep(_ items: [Migraine]) -> [Insight] {
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

    // MARK: - Weather association

    static func weather(_ items: [Migraine]) -> [Insight] {
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

        // Temperature extremes
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

    // MARK: - Menstrual phase association

    static func menstrualPhases(_ items: [Migraine]) -> [Insight] {
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
        guard let top = sorted.first, let bottom = sorted.last, top.1 - bottom.1 >= 1.0 else { return [] }

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

    // MARK: - Intensity patterns (how pain/stress evolve during migraines)

    static func intensityPatterns(_ items: [Migraine]) -> [Insight] {
        guard !items.isEmpty else { return [] }

        let migrainesWithSamples = items.filter { ($0.intensitySamples ?? []).count >= 2 }
        guard !migrainesWithSamples.isEmpty else { return [] }

        var results: [Insight] = []
        var increasingCount = 0
        var decreasingCount = 0
        var peakInFirstHalfCount = 0
        var peakInSecondHalfCount = 0
        var totalAnalyzed = 0
        var totalStressChange: [Int] = []

        for migraine in migrainesWithSamples {
            let samples = (migraine.intensitySamples ?? []).sorted { $0.timestamp < $1.timestamp }
            guard let first = samples.first, let last = samples.last, samples.count >= 2 else { continue }

            totalAnalyzed += 1

            if last.painLevel > first.painLevel + 1 {
                increasingCount += 1
            } else if last.painLevel < first.painLevel - 1 {
                decreasingCount += 1
            }

            if let peakIndex = samples.indices.max(by: { samples[$0].painLevel < samples[$1].painLevel }) {
                let midpoint = samples.count / 2
                if peakIndex < midpoint {
                    peakInFirstHalfCount += 1
                } else {
                    peakInSecondHalfCount += 1
                }
            }

            totalStressChange.append(last.stressLevel - first.stressLevel)
        }

        guard totalAnalyzed >= 3 else { return results }

        // Pain trend
        let increasingPct = Double(increasingCount) / Double(totalAnalyzed)
        let decreasingPct = Double(decreasingCount) / Double(totalAnalyzed)

        if increasingPct >= 0.5 {
            results.append(
                Insight(
                    category: .intensityPattern,
                    title: "Pain tends to build over time",
                    message: String(format: "%.0f%% of your migraines show increasing pain intensity.", increasingPct * 100),
                    priority: .medium,
                    tags: ["increasingPercent": increasingPct, "analyzed": totalAnalyzed]
                )
            )
        } else if decreasingPct >= 0.5 {
            results.append(
                Insight(
                    category: .intensityPattern,
                    title: "Pain tends to ease over time",
                    message: String(format: "%.0f%% of your migraines show decreasing pain intensity.", decreasingPct * 100),
                    priority: .low,
                    tags: ["decreasingPercent": decreasingPct, "analyzed": totalAnalyzed]
                )
            )
        }

        // Peak timing
        let earlyPeakPct = Double(peakInFirstHalfCount) / Double(totalAnalyzed)
        let latePeakPct = Double(peakInSecondHalfCount) / Double(totalAnalyzed)

        if earlyPeakPct >= 0.6 {
            results.append(
                Insight(
                    category: .intensityPeakTiming,
                    title: "Peak pain occurs early",
                    message: String(format: "%.0f%% of migraines reach peak intensity in the first half.", earlyPeakPct * 100),
                    priority: .medium,
                    tags: ["earlyPeakPercent": earlyPeakPct, "analyzed": totalAnalyzed]
                )
            )
        } else if latePeakPct >= 0.6 {
            results.append(
                Insight(
                    category: .intensityPeakTiming,
                    title: "Peak pain occurs later",
                    message: String(format: "%.0f%% of migraines reach peak intensity in the second half.", latePeakPct * 100),
                    priority: .medium,
                    tags: ["latePeakPercent": latePeakPct, "analyzed": totalAnalyzed]
                )
            )
        }

        // Stress change
        if !totalStressChange.isEmpty {
            let avgStressChange = Double(totalStressChange.reduce(0, +)) / Double(totalStressChange.count)
            if avgStressChange >= 2.0 {
                results.append(
                    Insight(
                        category: .intensityPattern,
                        title: "Stress increases during migraines",
                        message: String(format: "On average, stress increases by %.1f points during your migraines.", avgStressChange),
                        priority: .medium,
                        tags: ["avgStressChange": avgStressChange]
                    )
                )
            } else if avgStressChange <= -2.0 {
                results.append(
                    Insight(
                        category: .intensityPattern,
                        title: "Stress decreases during migraines",
                        message: String(format: "On average, stress decreases by %.1f points during your migraines.", abs(avgStressChange)),
                        priority: .low,
                        tags: ["avgStressChange": avgStressChange]
                    )
                )
            }
        }

        return results
    }

    // MARK: - Tag insights (frequency + severity correlation)

    static func tags(_ items: [Migraine]) -> [Insight] {
        guard !items.isEmpty else { return [] }

        let migrainesWithTags = items.filter { !($0.tags ?? []).isEmpty }
        guard !migrainesWithTags.isEmpty else { return [] }

        var results: [Insight] = []

        var tagCounts: [String: Int] = [:]
        var tagSeveritySum: [String: Int] = [:]
        var tagSeverityCount: [String: Int] = [:]

        for migraine in items {
            for tag in (migraine.tags ?? []) {
                tagCounts[tag.name, default: 0] += 1
                tagSeveritySum[tag.name, default: 0] += migraine.painLevel
                tagSeverityCount[tag.name, default: 0] += 1
            }
        }

        guard !tagCounts.isEmpty else { return [] }

        // Most common tag
        let total = items.count
        let sortedByFrequency = tagCounts.sorted { $0.value > $1.value }

        if let topTag = sortedByFrequency.first, topTag.value >= 3 {
            let pct = Double(topTag.value) / Double(total) * 100
            results.append(
                Insight(
                    category: .tagFrequency,
                    title: "Most common tag: \(topTag.key)",
                    message: String(format: "\"%@\" appears in %.0f%% of your migraines (%d total).", topTag.key, pct, topTag.value),
                    priority: pct >= 40 ? .medium : .low,
                    tags: ["tag": topTag.key, "count": topTag.value, "percent": pct]
                )
            )
        }

        // Severity correlation
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
                    title: "\"\(highest.name)\" linked to higher pain",
                    message: String(format: "Migraines tagged \"%@\" average %.1f pain vs %.1f overall.", highest.name, highest.avg, overallAvgSeverity),
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
                    title: "\"\(lowest.name)\" linked to lower pain",
                    message: String(format: "Migraines tagged \"%@\" average %.1f pain vs %.1f overall.", lowest.name, lowest.avg, overallAvgSeverity),
                    priority: .low,
                    tags: ["tag": lowest.name, "tagAvg": lowest.avg, "overallAvg": overallAvgSeverity]
                )
            )
        }

        // Tag co-occurrence
        var coOccurrences: [String: Int] = [:]
        for migraine in migrainesWithTags {
            let tags = (migraine.tags ?? []).map { $0.name }.sorted()
            guard tags.count >= 2 else { continue }
            for i in 0..<tags.count {
                for j in (i + 1)..<tags.count {
                    coOccurrences["\(tags[i]) + \(tags[j])", default: 0] += 1
                }
            }
        }

        if let topPair = coOccurrences.max(by: { $0.value < $1.value }), topPair.value >= 3 {
            results.append(
                Insight(
                    category: .tagFrequency,
                    title: "Tags often appear together",
                    message: "\"\(topPair.key)\" occur together in \(topPair.value) migraines.",
                    priority: .low,
                    tags: ["pair": topPair.key, "count": topPair.value]
                )
            )
        }

        return results
    }
}
