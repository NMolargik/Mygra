//
//  TestDataGenerator.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import Foundation
import SwiftData
import WeatherKit

#if DEBUG
/// Generates comprehensive test data for development and testing.
/// Only available in DEBUG builds.
@MainActor
struct TestDataGenerator {

    // MARK: - Public Interface

    /// Generates a complete set of test data including tags, migraines, health data,
    /// weather data, and intensity samples.
    static func generateTestData(context: ModelContext, tagManager: TagManager) {
        // 1. Create tags first
        let tags = createTags(tagManager: tagManager)

        // 2. Generate migraines over the last 4 weeks
        let migraines = createMigraines(context: context, tags: tags)

        // 3. Save the context
        try? context.save()

        print("🧪 Test data generated: \(tags.count) tags, \(migraines.count) migraines")
    }

    // MARK: - Tag Creation

    private static func createTags(tagManager: TagManager) -> [MigraineTag] {
        let tagDefinitions: [(name: String, hex: String)] = [
            ("Work Stress", "#EF4444"),      // Red
            ("Weather Related", "#3B82F6"),   // Blue
            ("Hormonal", "#EC4899"),          // Pink
            ("Food Trigger", "#F97316"),      // Orange
            ("Sleep Issues", "#8B5CF6"),      // Purple
            ("Exercise", "#10B981")           // Green
        ]

        var createdTags: [MigraineTag] = []
        for definition in tagDefinitions {
            let tag = tagManager.create(name: definition.name, colorHex: definition.hex)
            createdTags.append(tag)
        }
        return createdTags
    }

    // MARK: - Migraine Creation

    private static func createMigraines(context: ModelContext, tags: [MigraineTag]) -> [Migraine] {
        var migraines: [Migraine] = []
        let calendar = Calendar.current
        let now = Date()

        // Create 12-15 migraines spread over 4 weeks
        let migraineScenarios: [MigraineScenario] = [
            // Week 1 (most recent)
            MigraineScenario(
                daysAgo: 1, hoursAgo: 3,
                painLevel: 7, stressLevel: 8,
                triggers: [.stress, .lackOfSleep, .caffeineWithdrawal],
                customTriggers: ["Deadline pressure"],
                foods: ["Coffee", "Energy drink"],
                durationHours: 4.5,
                tagIndices: [0, 4], // Work Stress, Sleep Issues
                intensityPattern: .increasing,
                weatherCondition: .cloudy,
                note: "Started during important meeting"
            ),
            MigraineScenario(
                daysAgo: 3, hoursAgo: 14,
                painLevel: 5, stressLevel: 4,
                triggers: [.barometricPressureChange, .highHumidity],
                customTriggers: [],
                foods: [],
                durationHours: 3.0,
                tagIndices: [1], // Weather Related
                intensityPattern: .peaked,
                weatherCondition: .rain,
                note: "Pressure drop before storm"
            ),

            // Week 2
            MigraineScenario(
                daysAgo: 5, hoursAgo: 8,
                painLevel: 8, stressLevel: 6,
                triggers: [.hormonalFluctuation, .stress],
                customTriggers: [],
                foods: ["Chocolate"],
                durationHours: 6.0,
                tagIndices: [2, 0], // Hormonal, Work Stress
                intensityPattern: .increasing,
                weatherCondition: .partlyCloudy,
                note: nil
            ),
            MigraineScenario(
                daysAgo: 8, hoursAgo: 10,
                painLevel: 4, stressLevel: 3,
                triggers: [.brightLightGlare, .screenTimeFlicker],
                customTriggers: ["Long video call"],
                foods: [],
                durationHours: 2.0,
                tagIndices: [0], // Work Stress
                intensityPattern: .decreasing,
                weatherCondition: .clear,
                note: "Mild headache after extended screen time"
            ),
            MigraineScenario(
                daysAgo: 9, hoursAgo: 6,
                painLevel: 6, stressLevel: 7,
                triggers: [.intenseExercise, .dehydration],
                customTriggers: [],
                foods: [],
                durationHours: 3.5,
                tagIndices: [5], // Exercise
                intensityPattern: .peaked,
                weatherCondition: .hot,
                note: "After morning run"
            ),

            // Week 3
            MigraineScenario(
                daysAgo: 12, hoursAgo: 16,
                painLevel: 9, stressLevel: 9,
                triggers: [.stress, .lackOfSleep, .skippedMeals],
                customTriggers: ["Travel day"],
                foods: ["Fast food", "Soda"],
                durationHours: 8.0,
                tagIndices: [0, 3, 4], // Work Stress, Food Trigger, Sleep Issues
                intensityPattern: .increasing,
                weatherCondition: .strongStorms,
                note: "Worst migraine in weeks"
            ),
            MigraineScenario(
                daysAgo: 14, hoursAgo: 20,
                painLevel: 3, stressLevel: 2,
                triggers: [.alcoholRedWine],
                customTriggers: [],
                foods: ["Red wine", "Aged cheese", "Crackers"],
                durationHours: 1.5,
                tagIndices: [3], // Food Trigger
                intensityPattern: .decreasing,
                weatherCondition: .clear,
                note: "Mild after wine tasting"
            ),
            MigraineScenario(
                daysAgo: 16, hoursAgo: 4,
                painLevel: 6, stressLevel: 5,
                triggers: [.barometricPressureChange, .coldExtreme],
                customTriggers: [],
                foods: [],
                durationHours: 4.0,
                tagIndices: [1], // Weather Related
                intensityPattern: .peaked,
                weatherCondition: .frigid,
                note: nil
            ),

            // Week 4
            MigraineScenario(
                daysAgo: 20, hoursAgo: 12,
                painLevel: 7, stressLevel: 8,
                triggers: [.hormonalFluctuation],
                customTriggers: [],
                foods: ["Chocolate", "Ice cream"],
                durationHours: 5.0,
                tagIndices: [2, 3], // Hormonal, Food Trigger
                intensityPattern: .increasing,
                weatherCondition: .cloudy,
                note: nil
            ),
            MigraineScenario(
                daysAgo: 22, hoursAgo: 8,
                painLevel: 5, stressLevel: 4,
                triggers: [.loudNoise, .strongOdors],
                customTriggers: ["Concert"],
                foods: [],
                durationHours: 3.0,
                tagIndices: [],
                intensityPattern: .peaked,
                weatherCondition: .clear,
                note: "After concert last night"
            ),
            MigraineScenario(
                daysAgo: 25, hoursAgo: 18,
                painLevel: 4, stressLevel: 3,
                triggers: [.oversleeping],
                customTriggers: [],
                foods: [],
                durationHours: 2.5,
                tagIndices: [4], // Sleep Issues
                intensityPattern: .decreasing,
                weatherCondition: .foggy,
                note: "Weekend sleep-in headache"
            ),
            MigraineScenario(
                daysAgo: 27, hoursAgo: 6,
                painLevel: 8, stressLevel: 7,
                triggers: [.stress, .caffeineExcess, .postureNeckTension],
                customTriggers: ["Project deadline"],
                foods: ["Coffee", "Energy bar"],
                durationHours: 6.5,
                tagIndices: [0], // Work Stress
                intensityPattern: .increasing,
                weatherCondition: .partlyCloudy,
                note: "End of sprint crunch"
            ),

            // One ongoing migraine (no end date)
            MigraineScenario(
                daysAgo: 0, hoursAgo: 2,
                painLevel: 6, stressLevel: 5,
                triggers: [.eyeStrainBlueLight, .stress],
                customTriggers: [],
                foods: ["Coffee"],
                durationHours: nil, // Ongoing
                tagIndices: [0],
                intensityPattern: .increasing,
                weatherCondition: .mostlyCloudy,
                note: "Started this morning"
            )
        ]

        for scenario in migraineScenarios {
            guard let startDate = calendar.date(byAdding: .day, value: -scenario.daysAgo, to: now),
                  let adjustedStart = calendar.date(byAdding: .hour, value: -scenario.hoursAgo, to: startDate) else {
                continue
            }

            let endDate: Date?
            if let durationHours = scenario.durationHours {
                endDate = adjustedStart.addingTimeInterval(durationHours * 3600)
            } else {
                endDate = nil
            }

            // Create weather data
            let weather = createWeatherData(
                condition: scenario.weatherCondition,
                context: context
            )

            // Create health data
            let health = createHealthData(
                painLevel: scenario.painLevel,
                context: context
            )

            // Create migraine
            let migraine = Migraine(
                startDate: adjustedStart,
                endDate: endDate,
                painLevel: scenario.painLevel,
                stressLevel: scenario.stressLevel,
                note: scenario.note,
                triggers: scenario.triggers,
                customTriggers: scenario.customTriggers,
                foodsEaten: scenario.foods,
                weather: weather,
                health: health
            )

            // Assign tags
            var assignedTags: [MigraineTag] = []
            for index in scenario.tagIndices {
                if index < tags.count {
                    assignedTags.append(tags[index])
                }
            }
            migraine.tags = assignedTags

            // Insert migraine
            context.insert(migraine)

            // Create intensity samples
            createIntensitySamples(
                for: migraine,
                pattern: scenario.intensityPattern,
                context: context
            )

            migraines.append(migraine)
        }

        return migraines
    }

    // MARK: - Weather Data Creation

    private static func createWeatherData(condition: WeatherCondition, context: ModelContext) -> WeatherData {
        // Generate realistic weather values based on condition
        let (temp, pressure, humidity) = weatherValues(for: condition)

        let weather = WeatherData(
            barometricPressureHpa: pressure,
            temperatureCelsius: temp,
            humidityPercent: humidity,
            condition: condition,
            locationDescription: randomLocation()
        )

        context.insert(weather)
        return weather
    }

    private static func weatherValues(for condition: WeatherCondition) -> (temp: Double, pressure: Double, humidity: Double) {
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

    private static func randomLocation() -> String {
        let locations = [
            "San Francisco, CA",
            "New York, NY",
            "Seattle, WA",
            "Austin, TX",
            "Denver, CO",
            "Chicago, IL",
            "Boston, MA",
            "Portland, OR"
        ]
        return locations.randomElement() ?? "Unknown"
    }

    // MARK: - Health Data Creation

    private static func createHealthData(painLevel: Int, context: ModelContext) -> HealthData {
        // Generate health values - worse health metrics correlate with higher pain
        let poorHealthFactor = Double(painLevel) / 10.0

        let health = HealthData(
            waterLiters: Double.random(in: 0.8...2.5) * (1.0 - poorHealthFactor * 0.3),
            sleepHours: Double.random(in: 5.0...9.0) * (1.0 - poorHealthFactor * 0.2),
            energyKilocalories: Double.random(in: 1200...2500),
            caffeineMg: Double.random(in: 50...400) * (1.0 + poorHealthFactor * 0.3),
            stepCount: Int.random(in: 2000...12000),
            restingHeartRate: Int(Double.random(in: 55...75) * (1.0 + poorHealthFactor * 0.1)),
            bloodOxygenPercent: Double.random(in: 95...99),
            menstrualPhase: MenstrualPhase.allCases.randomElement()
        )

        context.insert(health)
        return health
    }

    // MARK: - Intensity Samples Creation

    private static func createIntensitySamples(
        for migraine: Migraine,
        pattern: IntensityPattern,
        context: ModelContext
    ) {
        guard let endDate = migraine.endDate else {
            // For ongoing migraines, create 2-3 samples
            createOngoingIntensitySamples(for: migraine, context: context)
            return
        }

        let duration = endDate.timeIntervalSince(migraine.startDate)
        let sampleCount = max(3, Int(duration / 3600)) // At least 3 samples, roughly 1 per hour

        var samples: [IntensitySample] = []

        for i in 0..<sampleCount {
            let progress = Double(i) / Double(sampleCount - 1)
            let timestamp = migraine.startDate.addingTimeInterval(duration * progress)

            let (pain, stress) = intensityValues(
                basePain: migraine.painLevel,
                baseStress: migraine.stressLevel,
                progress: progress,
                pattern: pattern
            )

            let sample = IntensitySample(
                timestamp: timestamp,
                painLevel: pain,
                stressLevel: stress,
                note: sampleNote(for: i, total: sampleCount, pattern: pattern),
                parentMigraine: migraine
            )

            context.insert(sample)
            samples.append(sample)
        }

        migraine.intensitySamples = samples
    }

    private static func createOngoingIntensitySamples(for migraine: Migraine, context: ModelContext) {
        var samples: [IntensitySample] = []

        // Initial sample at start
        let sample1 = IntensitySample(
            timestamp: migraine.startDate,
            painLevel: max(1, migraine.painLevel - 2),
            stressLevel: max(1, migraine.stressLevel - 1),
            note: "Just started",
            parentMigraine: migraine
        )
        context.insert(sample1)
        samples.append(sample1)

        // Sample 30 minutes later
        let sample2 = IntensitySample(
            timestamp: migraine.startDate.addingTimeInterval(1800),
            painLevel: migraine.painLevel - 1,
            stressLevel: migraine.stressLevel,
            note: nil,
            parentMigraine: migraine
        )
        context.insert(sample2)
        samples.append(sample2)

        // Current sample
        let sample3 = IntensitySample(
            timestamp: Date(),
            painLevel: migraine.painLevel,
            stressLevel: migraine.stressLevel,
            note: "Still ongoing",
            parentMigraine: migraine
        )
        context.insert(sample3)
        samples.append(sample3)

        migraine.intensitySamples = samples
    }

    private static func intensityValues(
        basePain: Int,
        baseStress: Int,
        progress: Double,
        pattern: IntensityPattern
    ) -> (pain: Int, stress: Int) {
        let variation: Double
        switch pattern {
        case .increasing:
            // Start low, end at base level
            variation = -3.0 * (1.0 - progress)
        case .decreasing:
            // Start at base, decrease over time
            variation = -3.0 * progress
        case .peaked:
            // Peak in the middle
            let peakProgress = 1.0 - abs(progress - 0.4) * 2.5
            variation = 2.0 * peakProgress - 1.0
        }

        let pain = max(1, min(10, basePain + Int(variation.rounded())))
        let stress = max(1, min(10, baseStress + Int((variation * 0.8).rounded())))

        return (pain, stress)
    }

    private static func sampleNote(for index: Int, total: Int, pattern: IntensityPattern) -> String? {
        if index == 0 {
            return "Initial symptoms"
        }
        if index == total - 1 {
            switch pattern {
            case .increasing:
                return "Peak reached"
            case .decreasing:
                return "Feeling better"
            case .peaked:
                return "Subsiding"
            }
        }
        if index == total / 2 && pattern == .peaked {
            return "Worst point"
        }
        return nil
    }

    // MARK: - Supporting Types

    enum IntensityPattern {
        case increasing
        case decreasing
        case peaked
    }

    struct MigraineScenario {
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
        let weatherCondition: WeatherCondition
        let note: String?
    }
}
#endif
