//
//  Migraine.swift
//  MygraCore
//
//  Central record type representing a migraine attack. CloudKit rules: defaults on every
//  attribute, optional relationships, no unique constraints.
//

import Foundation
import SwiftData

@Model
public final class Migraine {
    // MARK: - Identity & timestamps
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var pinned: Bool = false

    /// When symptoms began.
    public var startDate: Date = Date()
    /// When symptoms ended; nil if ongoing.
    public var endDate: Date?

    // MARK: - Symptom intensity
    /// Subjective pain 0–10.
    public var painLevel: Int = 0
    /// Subjective stress 0–10.
    public var stressLevel: Int = 0

    // MARK: - Notes & annotations
    public var note: String?
    /// AI-generated text insight at the time of logging.
    public var insight: String?

    // MARK: - Triggers & foods
    /// Triggers selected from the canonical trigger enum.
    public var triggers: [MigraineTrigger] = []
    /// Custom, free-form triggers provided by the user.
    public var customTriggers: [String] = []
    /// Foods eaten around the time of attack (freeform strings).
    public var foodsEaten: [String] = []

    // MARK: - Related data snapshots
    @Relationship(inverse: \WeatherData.migraine) public var weather: WeatherData?
    @Relationship(inverse: \HealthData.migraine) public var health: HealthData?

    // MARK: - User-defined tags
    @Relationship(inverse: \MigraineTag.migraines) public var tags: [MigraineTag]?

    // MARK: - Intensity samples (time-series)
    @Relationship(deleteRule: .cascade, inverse: \IntensitySample.parentMigraine)
    public var intensitySamples: [IntensitySample]?

    // MARK: - Init
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        pinned: Bool = false,
        startDate: Date,
        endDate: Date? = nil,
        painLevel: Int,
        stressLevel: Int,
        note: String? = nil,
        insight: String? = nil,
        triggers: [MigraineTrigger] = [],
        customTriggers: [String] = [],
        foodsEaten: [String] = [],
        weather: WeatherData? = nil,
        health: HealthData? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.pinned = pinned
        self.startDate = startDate
        self.endDate = endDate
        self.painLevel = painLevel
        self.stressLevel = stressLevel
        self.note = note
        self.insight = insight
        self.triggers = triggers
        self.customTriggers = customTriggers
        self.foodsEaten = foodsEaten
        self.weather = weather
        self.health = health
    }

    // MARK: - Computed properties

    public var isOngoing: Bool { endDate == nil }

    public var duration: TimeInterval? {
        guard let end = endDate else { return nil }
        return end.timeIntervalSince(startDate)
    }

    public var severity: Severity {
        Severity.from(painLevel: painLevel)
    }

    /// Alias for `pinned` following Swift naming conventions for Booleans.
    /// `pinned` is the persisted attribute name and is kept for CloudKit compatibility.
    public var isPinned: Bool {
        get { pinned }
        set { pinned = newValue }
    }

    /// Canonical trigger names followed by custom ones, de-duplicated case-insensitively.
    public var allTriggerNames: [String] {
        let custom = customTriggers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return (triggers.map(\.displayName) + custom).uniqued { $0.lowercased() }
    }

    /// Intensity samples ordered by timestamp.
    public var sortedIntensitySamples: [IntensitySample] {
        (intensitySamples ?? []).sorted { $0.timestamp < $1.timestamp }
    }
}

#if DEBUG
extension Migraine {
    /// A representative completed migraine for previews and tests.
    public static func sample(
        startDate: Date = Date().addingTimeInterval(-3 * 3600),
        endDate: Date? = Date().addingTimeInterval(-30 * 60),
        painLevel: Int = 6,
        stressLevel: Int = 5
    ) -> Migraine {
        Migraine(
            startDate: startDate,
            endDate: endDate,
            painLevel: painLevel,
            stressLevel: stressLevel,
            note: "Flickering lights and skipped lunch.",
            insight: "Lower sleep and higher stress may have contributed. You could try keeping a more regular meal schedule and short screen breaks. This is general, non-medical guidance and not a diagnosis.",
            triggers: [.stress, .skippedMeals],
            customTriggers: ["Bright lights"],
            foodsEaten: ["Coffee", "Salad"],
            weather: WeatherData(barometricPressureHpa: 1008, temperatureCelsius: 22, humidityPercent: 65, condition: .partlyCloudy, locationDescription: "Seattle, WA"),
            health: HealthData(waterLiters: 1.2, sleepHours: 6.5, energyKilocalories: 1800, caffeineMg: 120, stepCount: 5400, restingHeartRate: 58, activeHeartRate: 102, glucoseMgPerdL: 95, bloodOxygenPercent: 0.97)
        )
    }

    /// An ongoing migraine started two hours ago.
    public static func sampleOngoing() -> Migraine {
        Migraine(startDate: Date().addingTimeInterval(-2 * 3600), endDate: nil, painLevel: 7, stressLevel: 6, note: "Started this morning", triggers: [.eyeStrainBlueLight, .stress])
    }
}
#endif
