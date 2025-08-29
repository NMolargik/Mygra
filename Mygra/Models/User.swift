//
//  User.swift
//  Mygra
//
//  Created by Nick Molargik on 8/22/25.
//

import Foundation
import SwiftData

/// The single User profile for Mygra, synced via SwiftData + iCloud.
/// We enforce a single-row invariant using a unique `singletonKey`.
@Model
final class User {
    // MARK: - Singleton enforcement
    /// A constant unique key so only one `User` can exist in the store.
    /// Any attempt to insert a second `User` will violate uniqueness.
    var singletonKey: String = "USER_SINGLETON"

    // MARK: - Identity
    var name: String = ""
    var birthday: Date = Date.now

    // MARK: - Body characteristics (store in SI units)
    /// Biological sex as declared by the user. Keep this app-local to avoid
    /// HealthKit type coupling in the data model layer.
    var biologicalSex: BiologicalSex = BiologicalSex.female

    /// Height in **meters** (e.g., 1.78). Optional when unknown.
    var heightMeters: Double = 1.75

    /// Weight in **kilograms** (e.g., 72.5). Optional when unknown.
    var weightKilograms: Double = 70

    // MARK: - Health & lifestyle averages (user-declared or HealthKit-derived)
    /// Typical nightly sleep duration in **hours**.
    var averageSleepHours: Double = 8

    /// Typical daily caffeine intake in **milligrams**.
    var averageCaffeineMg: Double = 400

    // MARK: - Conditions & preferences
    var chronicConditions: [String] = []
    var dietaryRestrictions: [String] = []

    // MARK: - Metadata
    var createdAt: Date = Date()

    // MARK: - Init
    init(
        name: String = "",
        birthday: Date = Date.now,
        biologicalSex: BiologicalSex = BiologicalSex.female,
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
    
    var heightCentimeters: Double {
        get { heightMeters * 100.0 }
        set { heightMeters = newValue / 100.0 }
    }

    /// Height in inches, if set (derived from meters).
    var heightInches: Double {
        get { heightMeters * 39.37007874 }
        set { heightMeters = newValue / 39.37007874 }
    }

    /// Weight in pounds, if set (derived from kilograms).
    var weightPounds: Double {
        get { weightKilograms * 2.2046226218 }
        set { weightKilograms = newValue / 2.2046226218 }
    }

    /// Returns the height value to display given a unit preference.
    /// - Parameter useMetricUnits: true → centimeters, false → inches.
    func displayHeight(useMetricUnits: Bool) -> Double? {
        useMetricUnits ? heightCentimeters : heightInches
    }

    /// Sets the height from a UI value given a unit preference.
    /// - Parameter value: centimeters if metric, inches if imperial.
    func setDisplayHeight(_ value: Double, useMetricUnits: Bool) {
        if useMetricUnits { self.heightCentimeters = value } else { self.heightInches = value }
    }

    /// Returns the weight value to display given a unit preference.
    /// - Parameter useMetricUnits: true → kilograms, false → pounds.
    func displayWeight(useMetricUnits: Bool) -> Double? {
        useMetricUnits ? weightKilograms : weightPounds
    }

    /// Sets the weight from a UI value given a unit preference.
    /// - Parameter value: kilograms if metric, pounds if imperial.
    func setDisplayWeight(_ value: Double, useMetricUnits: Bool) {
        if useMetricUnits { self.weightKilograms = value } else { self.weightPounds = value }
    }
}

