//
//  DataExportUtility.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import Foundation

struct DataExportUtility {
    static func exportUserToCSV(user: User) -> String {
        let headers = [
            "id", "age", "sex", "height", "weight", "medications", "typicalCaffeineIntake",
            "hormonalCycleTracking", "typicalSleepHours", "dietaryRestrictions", "chronicConditions"
        ]
        let id = user.id.uuidString
        let age = user.age?.description ?? ""
        let sex = user.sex?.rawValue ?? ""
        let height = user.height?.description ?? ""
        let weight = user.weight?.description ?? ""
        let medications = user.medications?.map { $0 }.joined(separator: ";").csvEscaped ?? ""
        let typicalCaffeineIntake = user.typicalCaffeineIntake?.description ?? ""
        let hormonalCycleTracking = user.hormonalCycleTracking.description
        let typicalSleepHours = user.typicalSleepHours?.description ?? ""
        let dietaryRestrictions = user.dietaryRestrictions?.map { $0 }.joined(separator: ";").csvEscaped ?? ""
        let chronicConditions = user.chronicConditions?.map { $0 }.joined(separator: ";").csvEscaped ?? ""

        let row = [
            id, age, sex, height, weight, medications, typicalCaffeineIntake,
            hormonalCycleTracking, typicalSleepHours, dietaryRestrictions, chronicConditions
        ]
        return headers.joined(separator: ",") + "\n" + row.joined(separator: ",")
    }

    static func exportMigrainesToCSV(migraines: [Migraine]) -> String {
        let headers = [
            "id", "timestamp", "duration", "severity", "notes", "symptoms", "treatmentsTaken",
            "waterConsumed", "sleepHours", "caloriesConsumed", "restingHeartRate",
            "heartRateVariability", "barometricPressure", "temperature", "humidity",
            "environmentalNoise", "stepCount", "activeEnergy", "caffeineIntake",
            "menstrualPhase", "triggerFoodsConsumed", "sensoryOverload", "stressLevel",
            "medicationsTaken"
        ]
        let rows = migraines.map { migraine in
            let id = migraine.id.uuidString
            let timestamp = ISO8601DateFormatter().string(from: migraine.timestamp)
            let duration = migraine.duration?.description ?? ""
            let severity = migraine.severity?.rawValue ?? ""
            let notes = migraine.notes?.csvEscaped ?? ""
            let symptoms = migraine.symptoms?.map { $0.name }.joined(separator: ";").csvEscaped ?? ""
            let treatmentsTaken = migraine.treatmentsTaken?.map { $0.name }.joined(separator: ";").csvEscaped ?? ""
            let waterConsumed = migraine.waterConsumed?.description ?? ""
            let sleepHours = migraine.sleepHours?.description ?? ""
            let caloriesConsumed = migraine.caloriesConsumed?.description ?? ""
            let restingHeartRate = migraine.restingHeartRate?.description ?? ""
            let heartRateVariability = migraine.heartRateVariability?.description ?? ""
            let barometricPressure = migraine.barometricPressure?.description ?? ""
            let temperature = migraine.temperature?.description ?? ""
            let humidity = migraine.humidity?.description ?? ""
            let environmentalNoise = migraine.environmentalNoise?.description ?? ""
            let stepCount = migraine.stepCount?.description ?? ""
            let activeEnergy = migraine.activeEnergy?.description ?? ""
            let caffeineIntake = migraine.caffeineIntake?.description ?? ""
            let menstrualPhase = migraine.menstrualPhase?.rawValue ?? ""
            let triggerFoodsConsumed = migraine.triggerFoodsConsumed?.map { $0.name }.joined(separator: ";").csvEscaped ?? ""
            let sensoryOverload = migraine.sensoryOverload?.description ?? ""
            let stressLevel = migraine.stressLevel?.description ?? ""
            let medicationsTaken = migraine.medicationsTaken?.map { $0.name }.joined(separator: ";").csvEscaped ?? ""
            let row = [
                id, timestamp, duration, severity, notes, symptoms, treatmentsTaken, waterConsumed,
                sleepHours, caloriesConsumed, restingHeartRate, heartRateVariability, barometricPressure,
                temperature, humidity, environmentalNoise, stepCount, activeEnergy, caffeineIntake,
                menstrualPhase, triggerFoodsConsumed, sensoryOverload, stressLevel, medicationsTaken
            ]
            return row.joined(separator: ",")
        }
        return headers.joined(separator: ",") + "\n" + rows.joined(separator: "\n")
    }

    // Save CSV to file and return URL for sharing
    static func saveCSVToFile(content: String, fileName: String) -> URL? {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving CSV: \(error)")
            return nil
        }
    }
}
