//
//  Migraine.swift
//  Mygra
//
//  Created by Nick Molargik on 8/22/25.
//

import Foundation
import SwiftData

/// Central record type representing a migraine attack.
@Model
final class Migraine {
    // MARK: - Identity & timestamps
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var pinned: Bool = false

    /// When symptoms began.
    var startDate: Date = Date()
    /// When symptoms ended; nil if ongoing.
    var endDate: Date?

    // MARK: - Symptom intensity
    /// Subjective pain 0–10.
    var painLevel: Int = 0
    /// Subjective stress 0–10.
    var stressLevel: Int = 0

    // MARK: - Notes & annotations
    var note: String?
    /// AI-generated text insight at the time of logging.
    var insight: String?

    // MARK: - Triggers & foods
    /// Triggers selected from the canonical trigger enum.
    var triggers: [MigraineTrigger] = []
    /// Custom, free-form triggers provided by the user.
    var customTriggers: [String] = []
    /// Foods eaten around the time of attack (freeform strings).
    var foodsEaten: [String] = []

    // MARK: - Related data snapshots
    @Relationship(inverse: \WeatherData.migraine) var weather: WeatherData?
    @Relationship(inverse: \HealthData.migraine) var health: HealthData?

    // MARK: - User-defined tags
    @Relationship(inverse: \MigraineTag.migraines) var tags: [MigraineTag]?

    // MARK: - Intensity samples (time-series)
    @Relationship(deleteRule: .cascade, inverse: \IntensitySample.migraine)
    var intensitySamples: [IntensitySample]?

    // MARK: - Init
    init(
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

    var isOngoing: Bool { endDate == nil }

    var duration: TimeInterval? {
        guard let end = endDate else { return nil }
        return end.timeIntervalSince(startDate)
    }

    var severity: Severity {
        Severity.from(painLevel: painLevel)
    }

    /// Alias for `pinned` following Swift naming conventions for Booleans.
    /// Use this property in new code; `pinned` is kept for SwiftData compatibility.
    var isPinned: Bool {
        get { pinned }
        set { pinned = newValue }
    }
}

