//
//  Migraine.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import SwiftUI
import SwiftData

// Define wrapper structs for your array properties
struct Symptom: Codable, Hashable {
    let name: String
}

struct Treatment: Codable, Hashable {
    let name: String
}

struct TriggerFood: Codable, Hashable {
    let name: String
}

struct Medication: Codable, Hashable {
    let name: String
}

// Assuming your User model has similar arrays (based on the error logs), you'd do the same:
// struct DietaryRestriction: Codable, Hashable { let name: String }
// struct ChronicCondition: Codable, Hashable { let name: String }
// etc.

@Model
final class Migraine {
    var id: UUID = UUID()
    var isPinned: Bool = false
    var timestamp: Date = Date()
    var duration: TimeInterval?
    var severity: Severity?
    var notes: String?
    @Attribute(.externalStorage) var symptoms: [Symptom]? // Now an array of structs
    @Attribute(.externalStorage) var treatmentsTaken: [Treatment]?
    // Trigger-related properties
    var waterConsumed: Double? // Liters
    var sleepHours: Double?
    var caloriesConsumed: Double? // kcal
    var restingHeartRate: Double? // bpm
    var heartRateVariability: Double? // ms
    var barometricPressure: Double? // hPa
    var temperature: Double? // Celsius
    var humidity: Double? // %
    var environmentalNoise: Double? // dB
    var stepCount: Int?
    var activeEnergy: Double? // kcal
    var caffeineIntake: Double? // mg
    var menstrualPhase: MenstrualPhase?
    @Attribute(.externalStorage) var triggerFoodsConsumed: [TriggerFood]?
    var sensoryOverload: Bool?
    var stressLevel: Int? // 1-10
    @Attribute(.externalStorage) var medicationsTaken: [Medication]?
    
    // Many-to-one relationship to User
    var user: User?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), duration: TimeInterval? = nil, severity: Severity? = nil,
         notes: String? = nil, symptoms: [Symptom]? = nil, treatmentsTaken: [Treatment]? = nil,
         waterConsumed: Double? = nil, sleepHours: Double? = nil, caloriesConsumed: Double? = nil,
         restingHeartRate: Double? = nil, heartRateVariability: Double? = nil, barometricPressure: Double? = nil,
         temperature: Double? = nil, humidity: Double? = nil, environmentalNoise: Double? = nil,
         stepCount: Int? = nil, activeEnergy: Double? = nil, caffeineIntake: Double? = nil,
         menstrualPhase: MenstrualPhase? = nil, triggerFoodsConsumed: [TriggerFood]? = nil,
         sensoryOverload: Bool? = nil, stressLevel: Int? = nil, medicationsTaken: [Medication]? = nil,
         user: User? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.duration = duration
        self.severity = severity
        self.notes = notes
        self.symptoms = symptoms
        self.treatmentsTaken = treatmentsTaken
        self.waterConsumed = waterConsumed
        self.sleepHours = sleepHours
        self.caloriesConsumed = caloriesConsumed
        self.restingHeartRate = restingHeartRate
        self.heartRateVariability = heartRateVariability
        self.barometricPressure = barometricPressure
        self.temperature = temperature
        self.humidity = humidity
        self.environmentalNoise = environmentalNoise
        self.stepCount = stepCount
        self.activeEnergy = activeEnergy
        self.caffeineIntake = caffeineIntake
        self.menstrualPhase = menstrualPhase
        self.triggerFoodsConsumed = triggerFoodsConsumed
        self.sensoryOverload = sensoryOverload
        self.stressLevel = stressLevel
        self.medicationsTaken = medicationsTaken
        self.user = user
    }
    
    // Enums remain the same
    enum Severity: String, Codable, CaseIterable {
        case mild = "Mild"
        case moderate = "Moderate"
        case severe = "Severe"
        
        var color: Color {
            switch self {
            case .mild: return .green
            case .moderate: return .orange
            case .severe: return .red
            }
        }
    }
    
    enum MenstrualPhase: String, Codable, CaseIterable {
        case menstruation = "Menstruation"
        case follicular = "Follicular"
        case ovulation = "Ovulation"
        case luteal = "Luteal"
        case none = "None"
    }
}
