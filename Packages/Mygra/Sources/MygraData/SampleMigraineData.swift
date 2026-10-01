//
//  SampleMigraineData.swift
//  MygraData
//
//  DEBUG-only generator of tags and ~13 migraines (with health, weather, intensity
//  samples, and tags) spread over the last four weeks — used by the Settings developer
//  menu, previews, and screenshots.
//

#if DEBUG
import Foundation
import MygraCore
import os

@MainActor
public struct SampleMigraineData: GenerateSampleData {

    private let migraines: any MigraineRepository
    private let tags: any TagRepository
    private let calendar: Calendar
    private let now: Date

    public init(migraines: any MigraineRepository, tags: any TagRepository, calendar: Calendar = .current, now: Date = Date()) {
        self.migraines = migraines
        self.tags = tags
        self.calendar = calendar
        self.now = now
    }

    public func callAsFunction() throws(PersistenceError) {
        try generate()
    }

    /// Seeds the demo data set. Idempotent per tag name (existing tags are reused).
    public func generate() throws(PersistenceError) {
        Log.migraine.info("Generating sample migraine data")
        let createdTags = try createTags()
        for scenario in Self.scenarios {
            guard let migraine = makeMigraine(from: scenario, tags: createdTags) else { continue }
            try migraines.insert(migraine)
            try seedIntensitySamples(for: migraine, pattern: scenario.intensityPattern)
        }
    }

    // MARK: - Tags

    private static let tagDefinitions: [(name: String, hex: String)] = [
        ("Work Stress", "#EF4444"),
        ("Weather Related", "#3B82F6"),
        ("Hormonal", "#EC4899"),
        ("Food Trigger", "#F97316"),
        ("Sleep Issues", "#8B5CF6"),
        ("Exercise", "#10B981"),
    ]

    private func createTags() throws(PersistenceError) -> [MigraineTag] {
        let existing = try tags.tags()
        var result: [MigraineTag] = []
        for definition in Self.tagDefinitions {
            if let found = existing.first(where: { $0.name == definition.name }) {
                result.append(found)
            } else {
                result.append(try tags.create(name: definition.name, colorHex: definition.hex))
            }
        }
        return result
    }

    // MARK: - Migraines

    private func makeMigraine(from scenario: Scenario, tags: [MigraineTag]) -> Migraine? {
        guard let day = calendar.date(byAdding: .day, value: -scenario.daysAgo, to: now),
              let start = calendar.date(byAdding: .hour, value: -scenario.hoursAgo, to: day) else {
            return nil
        }
        let end = scenario.durationHours.map { start.addingTimeInterval($0 * 3600) }

        let migraine = Migraine(
            startDate: start,
            endDate: end,
            painLevel: scenario.painLevel,
            stressLevel: scenario.stressLevel,
            note: scenario.note,
            triggers: scenario.triggers,
            customTriggers: scenario.customTriggers,
            foodsEaten: scenario.foods,
            weather: makeWeather(condition: scenario.condition),
            health: makeHealth(painLevel: scenario.painLevel)
        )
        migraine.tags = scenario.tagIndices.compactMap { index in
            index < tags.count ? tags[index] : nil
        }
        return migraine
    }

    private func makeWeather(condition: SkyCondition) -> WeatherData {
        let (temp, pressure, humidity) = Self.weatherValues(for: condition)
        return WeatherData(
            barometricPressureHpa: pressure,
            temperatureCelsius: temp,
            humidityPercent: humidity,
            condition: condition,
            locationDescription: Self.locations.randomElement()
        )
    }

    private static func weatherValues(for condition: SkyCondition) -> (temp: Double, pressure: Double, humidity: Double) {
        switch condition {
        case .clear, .mostlyClear:
            return (Double.random(in: 18...28), Double.random(in: 1015...1025), Double.random(in: 30...50))
        case .partlyCloudy:
            return (Double.random(in: 15...25), Double.random(in: 1010...1020), Double.random(in: 40...60))
        case .cloudy, .mostlyCloudy:
            return (Double.random(in: 12...20), Double.random(in: 1005...1015), Double.random(in: 50...70))
        case .rain, .drizzle:
            return (Double.random(in: 10...18), Double.random(in: 1000...1010), Double.random(in: 70...90))
        case .strongStorms:
            return (Double.random(in: 15...25), Double.random(in: 995...1005), Double.random(in: 80...95))
        case .frigid:
            return (Double.random(in: -10...0), Double.random(in: 1020...1035), Double.random(in: 40...60))
        case .hot:
            return (Double.random(in: 30...38), Double.random(in: 1008...1018), Double.random(in: 30...50))
        case .foggy:
            return (Double.random(in: 8...15), Double.random(in: 1010...1020), Double.random(in: 85...100))
        default:
            return (Double.random(in: 15...22), Double.random(in: 1010...1020), Double.random(in: 50...70))
        }
    }

    private static let locations = [
        "San Francisco, CA", "New York, NY", "Seattle, WA", "Austin, TX",
        "Denver, CO", "Chicago, IL", "Boston, MA", "Portland, OR",
    ]

    private func makeHealth(painLevel: Int) -> HealthData {
        // Worse health metrics correlate with higher pain.
        let poorHealthFactor = Double(painLevel) / 10.0
        return HealthData(
            waterLiters: Double.random(in: 0.8...2.5) * (1.0 - poorHealthFactor * 0.3),
            sleepHours: Double.random(in: 5.0...9.0) * (1.0 - poorHealthFactor * 0.2),
            energyKilocalories: Double.random(in: 1200...2500),
            caffeineMg: Double.random(in: 50...400) * (1.0 + poorHealthFactor * 0.3),
            stepCount: Int.random(in: 2000...12000),
            restingHeartRate: Int(Double.random(in: 55...75) * (1.0 + poorHealthFactor * 0.1)),
            bloodOxygenPercent: Double.random(in: 0.95...0.99),
            menstrualPhase: MenstrualPhase.allCases.randomElement()
        )
    }

    // MARK: - Intensity samples

    private func seedIntensitySamples(for migraine: Migraine, pattern: IntensityPattern) throws(PersistenceError) {
        // `insert` already recorded the sample at the start; add the rest of the curve.
        guard let end = migraine.endDate else {
            let start = migraine.startDate
            try migraines.addIntensitySample(to: migraine, timestamp: start.addingTimeInterval(1800), painLevel: max(1, migraine.painLevel - 1), stressLevel: migraine.stressLevel, note: nil)
            try migraines.addIntensitySample(to: migraine, timestamp: now, painLevel: migraine.painLevel, stressLevel: migraine.stressLevel, note: "Still ongoing")
            return
        }

        let basePain = migraine.painLevel
        let baseStress = migraine.stressLevel
        let duration = end.timeIntervalSince(migraine.startDate)
        let sampleCount = max(3, Int(duration / 3600))

        for index in 1..<sampleCount {
            let progress = Double(index) / Double(sampleCount - 1)
            let timestamp = migraine.startDate.addingTimeInterval(duration * progress)
            let (pain, stress) = Self.intensityValues(basePain: basePain, baseStress: baseStress, progress: progress, pattern: pattern)
            try migraines.addIntensitySample(
                to: migraine,
                timestamp: timestamp,
                painLevel: pain,
                stressLevel: stress,
                note: Self.sampleNote(for: index, total: sampleCount, pattern: pattern)
            )
        }
        // Restore the headline levels the scenario asked for.
        try migraines.update(migraine) { m in
            m.painLevel = basePain
            m.stressLevel = baseStress
        }
    }

    private static func intensityValues(basePain: Int, baseStress: Int, progress: Double, pattern: IntensityPattern) -> (pain: Int, stress: Int) {
        let variation: Double
        switch pattern {
        case .increasing:
            variation = -3.0 * (1.0 - progress)
        case .decreasing:
            variation = -3.0 * progress
        case .peaked:
            let peakProgress = 1.0 - abs(progress - 0.4) * 2.5
            variation = 2.0 * peakProgress - 1.0
        }
        let pain = max(1, min(10, basePain + Int(variation.rounded())))
        let stress = max(1, min(10, baseStress + Int((variation * 0.8).rounded())))
        return (pain, stress)
    }

    private static func sampleNote(for index: Int, total: Int, pattern: IntensityPattern) -> String? {
        if index == total - 1 {
            switch pattern {
            case .increasing: return "Peak reached"
            case .decreasing: return "Feeling better"
            case .peaked: return "Subsiding"
            }
        }
        if index == total / 2 && pattern == .peaked {
            return "Worst point"
        }
        return nil
    }

    // MARK: - Scenarios

    enum IntensityPattern {
        case increasing, decreasing, peaked
    }

    struct Scenario {
        let daysAgo: Int
        let hoursAgo: Int
        let painLevel: Int
        let stressLevel: Int
        let triggers: [MigraineTrigger]
        let customTriggers: [String]
        let foods: [String]
        let durationHours: Double?
        let tagIndices: [Int]
        let intensityPattern: IntensityPattern
        let condition: SkyCondition
        let note: String?
    }

    static let scenarios: [Scenario] = [
        Scenario(daysAgo: 1, hoursAgo: 3, painLevel: 7, stressLevel: 8, triggers: [.stress, .lackOfSleep, .caffeineWithdrawal], customTriggers: ["Deadline pressure"], foods: ["Coffee", "Energy drink"], durationHours: 4.5, tagIndices: [0, 4], intensityPattern: .increasing, condition: .cloudy, note: "Started during important meeting"),
        Scenario(daysAgo: 3, hoursAgo: 14, painLevel: 5, stressLevel: 4, triggers: [.barometricPressureChange, .highHumidity], customTriggers: [], foods: [], durationHours: 3.0, tagIndices: [1], intensityPattern: .peaked, condition: .rain, note: "Pressure drop before storm"),
        Scenario(daysAgo: 5, hoursAgo: 8, painLevel: 8, stressLevel: 6, triggers: [.hormonalFluctuation, .stress], customTriggers: [], foods: ["Chocolate"], durationHours: 6.0, tagIndices: [2, 0], intensityPattern: .increasing, condition: .partlyCloudy, note: nil),
        Scenario(daysAgo: 8, hoursAgo: 10, painLevel: 4, stressLevel: 3, triggers: [.brightLightGlare, .screenTimeFlicker], customTriggers: ["Long video call"], foods: [], durationHours: 2.0, tagIndices: [0], intensityPattern: .decreasing, condition: .clear, note: "Mild headache after extended screen time"),
        Scenario(daysAgo: 9, hoursAgo: 6, painLevel: 6, stressLevel: 7, triggers: [.intenseExercise, .dehydration], customTriggers: [], foods: [], durationHours: 3.5, tagIndices: [5], intensityPattern: .peaked, condition: .hot, note: "After morning run"),
        Scenario(daysAgo: 12, hoursAgo: 16, painLevel: 9, stressLevel: 9, triggers: [.stress, .lackOfSleep, .skippedMeals], customTriggers: ["Travel day"], foods: ["Fast food", "Soda"], durationHours: 8.0, tagIndices: [0, 3, 4], intensityPattern: .increasing, condition: .strongStorms, note: "Worst migraine in weeks"),
        Scenario(daysAgo: 14, hoursAgo: 20, painLevel: 3, stressLevel: 2, triggers: [.alcoholRedWine], customTriggers: [], foods: ["Red wine", "Aged cheese", "Crackers"], durationHours: 1.5, tagIndices: [3], intensityPattern: .decreasing, condition: .clear, note: "Mild after wine tasting"),
        Scenario(daysAgo: 16, hoursAgo: 4, painLevel: 6, stressLevel: 5, triggers: [.barometricPressureChange, .coldExtreme], customTriggers: [], foods: [], durationHours: 4.0, tagIndices: [1], intensityPattern: .peaked, condition: .frigid, note: nil),
        Scenario(daysAgo: 20, hoursAgo: 12, painLevel: 7, stressLevel: 8, triggers: [.hormonalFluctuation], customTriggers: [], foods: ["Chocolate", "Ice cream"], durationHours: 5.0, tagIndices: [2, 3], intensityPattern: .increasing, condition: .cloudy, note: nil),
        Scenario(daysAgo: 22, hoursAgo: 8, painLevel: 5, stressLevel: 4, triggers: [.loudNoise, .strongOdors], customTriggers: ["Concert"], foods: [], durationHours: 3.0, tagIndices: [], intensityPattern: .peaked, condition: .clear, note: "After concert last night"),
        Scenario(daysAgo: 25, hoursAgo: 18, painLevel: 4, stressLevel: 3, triggers: [.oversleeping], customTriggers: [], foods: [], durationHours: 2.5, tagIndices: [4], intensityPattern: .decreasing, condition: .foggy, note: "Weekend sleep-in headache"),
        Scenario(daysAgo: 27, hoursAgo: 6, painLevel: 8, stressLevel: 7, triggers: [.stress, .caffeineExcess, .postureNeckTension], customTriggers: ["Project deadline"], foods: ["Coffee", "Energy bar"], durationHours: 6.5, tagIndices: [0], intensityPattern: .increasing, condition: .partlyCloudy, note: "End of sprint crunch"),
        // One ongoing migraine (no end date)
        Scenario(daysAgo: 0, hoursAgo: 2, painLevel: 6, stressLevel: 5, triggers: [.eyeStrainBlueLight, .stress], customTriggers: [], foods: ["Coffee"], durationHours: nil, tagIndices: [0], intensityPattern: .increasing, condition: .mostlyCloudy, note: "Started this morning"),
    ]
}
#endif
