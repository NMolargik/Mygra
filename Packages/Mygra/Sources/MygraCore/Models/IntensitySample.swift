//
//  IntensitySample.swift
//  MygraCore
//
//  A time-series sample of migraine intensity: pain and stress at a moment during an
//  attack.
//

import Foundation
import SwiftData

@Model
public final class IntensitySample {
    // MARK: - Identity
    public var id: UUID = UUID()
    public var createdAt: Date = Date()

    /// When this intensity sample was recorded.
    public var timestamp: Date = Date()

    /// Pain level at this point (0-10 scale).
    public var painLevel: Int = 0
    /// Stress level at this point (0-10 scale).
    public var stressLevel: Int = 0

    /// A brief note about how the user is feeling at this sample.
    public var note: String?

    /// The migraine this sample belongs to.
    public var parentMigraine: Migraine?

    // MARK: - Init
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        timestamp: Date = Date(),
        painLevel: Int = 0,
        stressLevel: Int = 0,
        note: String? = nil,
        parentMigraine: Migraine? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.timestamp = timestamp
        self.painLevel = painLevel
        self.stressLevel = stressLevel
        self.note = note
        self.parentMigraine = parentMigraine
    }

    // MARK: - Computed

    public var severity: Severity {
        Severity.from(painLevel: painLevel)
    }

    /// Time since the migraine started (for chart X-axis).
    public var timeSinceStart: TimeInterval? {
        guard let migraine = parentMigraine else { return nil }
        return timestamp.timeIntervalSince(migraine.startDate)
    }

    /// Formatted time since start (e.g., "1h 30m").
    public var formattedTimeSinceStart: String? {
        timeSinceStart.map(MigraineDates.compactDurationString)
    }
}
