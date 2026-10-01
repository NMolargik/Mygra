//
//  User.swift
//  MygraCore
//
//  The single User profile, synced via SwiftData + iCloud. The single-row invariant is
//  enforced in the repository (CloudKit-backed stores can't use uniqueness constraints).
//

import Foundation
import SwiftData

@Model
public final class User {
    /// Default birthday for new users: 18 years ago from today.
    public static var defaultBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    // MARK: - Identity
    public var name: String = ""
    public var birthday: Date = User.defaultBirthday

    // MARK: - Body characteristics (SI units)
    public var biologicalSex: BiologicalSex = BiologicalSex.female
    /// Height in meters.
    public var heightMeters: Double = 1.75
    /// Weight in kilograms.
    public var weightKilograms: Double = 70

    // MARK: - Health & lifestyle averages
    /// Typical nightly sleep duration in hours.
    public var averageSleepHours: Double = 8
    /// Typical daily caffeine intake in milligrams.
    public var averageCaffeineMg: Double = 400

    // MARK: - Conditions & preferences
    public var chronicConditions: [String] = []
    public var dietaryRestrictions: [String] = []

    // MARK: - Metadata
    public var createdAt: Date = Date()

    // MARK: - Init
    public init(
        name: String = "",
        birthday: Date = User.defaultBirthday,
        biologicalSex: BiologicalSex = .female,
        heightMeters: Double = 1.75,
        weightKilograms: Double = 70,
        averageSleepHours: Double = 8,
        averageCaffeineMg: Double = 400,
        chronicConditions: [String] = [],
        dietaryRestrictions: [String] = [],
        createdAt: Date = Date()
    ) {
        self.name = name
        self.birthday = birthday
        self.biologicalSex = biologicalSex
        self.heightMeters = heightMeters
        self.weightKilograms = weightKilograms
        self.averageSleepHours = averageSleepHours
        self.averageCaffeineMg = averageCaffeineMg
        self.chronicConditions = chronicConditions
        self.dietaryRestrictions = dietaryRestrictions
        self.createdAt = createdAt
    }

    // MARK: - Derived units

    public var heightCentimeters: Double {
        get { heightMeters * 100.0 }
        set { heightMeters = newValue / 100.0 }
    }

    public var heightInches: Double {
        get { heightMeters * UnitConversion.metersToInches }
        set { heightMeters = newValue / UnitConversion.metersToInches }
    }

    public var weightPounds: Double {
        get { weightKilograms * UnitConversion.kilogramsToPounds }
        set { weightKilograms = newValue / UnitConversion.kilogramsToPounds }
    }

    /// Height for a unit preference: centimeters (metric) or inches.
    public func displayHeight(useMetricUnits: Bool) -> Double {
        useMetricUnits ? heightCentimeters : heightInches
    }

    /// Weight for a unit preference: kilograms (metric) or pounds.
    public func displayWeight(useMetricUnits: Bool) -> Double {
        useMetricUnits ? weightKilograms : weightPounds
    }

    /// Copies every editable field from `other` (used to apply form edits to the managed row).
    public func apply(_ other: User) {
        name = other.name
        birthday = other.birthday
        biologicalSex = other.biologicalSex
        heightMeters = other.heightMeters
        weightKilograms = other.weightKilograms
        averageSleepHours = other.averageSleepHours
        averageCaffeineMg = other.averageCaffeineMg
        chronicConditions = other.chronicConditions
        dietaryRestrictions = other.dietaryRestrictions
    }
}
