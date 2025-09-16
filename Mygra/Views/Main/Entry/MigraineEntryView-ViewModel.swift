//
//  MigraineEntryView-ViewModel.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import SwiftUI

extension MigraineEntryView {
    @MainActor
    @Observable
    class ViewModel {
        // Local state to drive capsule UI
        var isPullingHealth = true
        var didPullHealth = false
        var healthError: Error?

        var isPullingWeather = true
        var didPullWeather = false
        var weatherError: Error?

        // Entry form state
        var startDate: Date = Date()
        var isOngoing: Bool = false
        var endDate: Date = Date()
        var painLevel: Int = 5
        var stressLevel: Int = 5
        var selectedTriggers: Set<MigraineTrigger> = []
        // Custom triggers
        var customTriggerInput: String = ""
        var customTriggers: [String] = []
        var foodsText: String = ""
        var noteText: String = ""
        var pinned: Bool = false

        // UI helpers
        var triggerSearchText: String = ""
        var showValidationAlert: Bool = false
        var validationMessage: String = ""

        // Intake editing state (moved from @State in the view)
        var isEditingHealthValues: Bool = false
        var isSavingHealthEdits: Bool = false
        var healthEditErrorMessage: String?
        var addWater: Double = 0.0
        var addCalories: Double = 0.0
        var addCaffeine: Double = 0.0
        var addSleepHours: Double = 0.0
        var allAddsAreZero: Bool { addWater == 0 && addCalories == 0 && addCaffeine == 0 && addSleepHours == 0 }

        // Dynamic empathetic/helpful greeting
        var greeting: String = ""
        let greetingOptions: [String] = [
            "We’ve got you.",
            "We’ll help you through this!",
            "Sorry you’re dealing with this...",
            "Let’s get you some relief.",
            "Here to help."
        ]

        // MARK: - Convenience mutations

        func setOngoing(_ ongoing: Bool) {
            isOngoing = ongoing
            if !ongoing {
                if endDate < startDate {
                    endDate = max(Date(), startDate)
                }
            }
        }

        func toggleTrigger(_ trigger: MigraineTrigger) {
            if selectedTriggers.contains(trigger) {
                selectedTriggers.remove(trigger)
            } else {
                selectedTriggers.insert(trigger)
            }
        }

        func addCustomTrigger() {
            let trimmed = customTriggerInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            // Prevent duplicates case-insensitively
            let exists = customTriggers.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
            guard !exists else {
                customTriggerInput = ""
                return
            }
            // Store in title case for display
            let display = trimmed.capitalized
            customTriggers.append(display)
            customTriggerInput = ""
        }

        func removeCustomTrigger(at index: Int) {
            guard index >= 0 && index < customTriggers.count else { return }
            customTriggers.remove(at: index)
        }

        func parseFoods() -> [String] {
            foodsText
                .components(separatedBy: CharacterSet(charactersIn: ",\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        @discardableResult
        func validateBeforeSave() -> Bool {
            if !isOngoing && endDate < startDate {
                validationMessage = "End time must be after the start time."
                showValidationAlert = true
                return false
            }
            if painLevel < 0 || painLevel > 10 || stressLevel < 0 || stressLevel > 10 {
                validationMessage = "Pain and stress levels must be between 0 and 10."
                showValidationAlert = true
                return false
            }
            validationMessage = ""
            showValidationAlert = false
            return true
        }

        func resetGreeting() {
            greeting = greetingOptions.randomElement() ?? ""
        }
    }
}
