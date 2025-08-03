//
//  User.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import SwiftData
import Foundation

@Model
final class User {
    var id: UUID = UUID()
    var age: Int?
    var sex: BiologicalSex?
    var height: Double? // cm
    var weight: Double? // kg
    @Attribute(.externalStorage) var medications: [String]? // Stored as Data if large
    var typicalCaffeineIntake: Double? // mg
    var hormonalCycleTracking: Bool = false
    var typicalSleepHours: Double?
    @Attribute(.externalStorage) var dietaryRestrictions: [String]?
    @Attribute(.externalStorage) var chronicConditions: [String]?

    // One-to-many relationship to Migraine
    @Relationship(deleteRule: .cascade, inverse: \Migraine.user)
    var migraines: [Migraine]? = nil

    init(id: UUID = UUID(), age: Int? = nil, sex: BiologicalSex? = nil, height: Double? = nil, weight: Double? = nil,
         medications: [String]? = nil, typicalCaffeineIntake: Double? = nil, hormonalCycleTracking: Bool = false,
         typicalSleepHours: Double? = nil, dietaryRestrictions: [String]? = nil, chronicConditions: [String]? = nil,
         migraines: [Migraine]? = nil) {
        self.id = id
        self.age = age
        self.sex = sex
        self.height = height
        self.weight = weight
        self.medications = medications
        self.typicalCaffeineIntake = typicalCaffeineIntake
        self.hormonalCycleTracking = hormonalCycleTracking
        self.typicalSleepHours = typicalSleepHours
        self.dietaryRestrictions = dietaryRestrictions
        self.chronicConditions = chronicConditions
        self.migraines = migraines
    }

    enum BiologicalSex: String, Codable {
        case female = "Female"
        case male = "Male"
        case other = "Other"
    }
}
