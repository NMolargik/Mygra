//
//  IntensitySample.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import Foundation
import SwiftData

/// A time-series sample of migraine intensity.
/// Tracks pain and stress levels at a specific point during a migraine.
@Model
final class IntensitySample {
    // MARK: - Identity
    var id: UUID = UUID()
    var createdAt: Date = Date()

    // MARK: - Timestamp
    /// When this intensity sample was recorded.
    var timestamp: Date = Date()

    // MARK: - Intensity Values
    /// Pain level at this point (0-10 scale).
    var painLevel: Int = 0

    /// Stress level at this point (0-10 scale).
    var stressLevel: Int = 0

    // MARK: - Optional Note
    /// A brief note about how the user is feeling at this sample.
    var note: String?

    // MARK: - Relationship
    /// The migraine this sample belongs to.
    var parentMigraine: Migraine?

    // MARK: - Init
    init(
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

    // MARK: - Computed Properties

    /// The severity derived from pain level.
    var severity: Severity {
        Severity.from(painLevel: painLevel)
    }

    /// Time since the migraine started (for chart X-axis).
    var timeSinceStart: TimeInterval? {
        guard let migraine = parentMigraine else { return nil }
        return timestamp.timeIntervalSince(migraine.startDate)
    }

    /// Formatted time since start (e.g., "1h 30m").
    var formattedTimeSinceStart: String? {
        guard let interval = timeSinceStart else { return nil }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
