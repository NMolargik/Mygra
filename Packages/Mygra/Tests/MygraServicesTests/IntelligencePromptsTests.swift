//
//  IntelligencePromptsTests.swift
//  MygraServicesTests
//
//  The pure prompt builders and response parsing behind the Foundation Models calls.
//

import Foundation
import Testing
import MygraCore
@testable import MygraServices

@Suite("IntelligencePrompts")
@MainActor
struct IntelligencePromptsTests {
    @Test func analysisPromptIncludesTheMigraineFields() {
        let migraine = Migraine(startDate: Date().addingTimeInterval(-7200), endDate: Date(), painLevel: 8, stressLevel: 4, note: "Long day", triggers: [.stress], customTriggers: ["deadline"], foodsEaten: ["Coffee"])
        migraine.health = HealthData(waterLiters: 1.0, sleepHours: 5.5)
        migraine.weather = WeatherData(barometricPressureHpa: 1005, temperatureCelsius: 20, humidityPercent: 60, condition: .rain)

        let prompt = IntelligencePrompts.analysisPrompt(migraine: migraine, user: User(name: "Nick"))
        #expect(prompt.contains("User: Nick"))
        #expect(prompt.contains("Pain: 8/10, Stress: 4/10"))
        #expect(prompt.contains("Duration: 2.0 hours"))
        #expect(prompt.contains("Selected triggers: Stress, deadline"))
        #expect(prompt.contains("Foods: Coffee"))
        #expect(prompt.contains("sleep=5.5h"))
        #expect(prompt.contains("condition=rain"))
        #expect(prompt.contains("Note: Long day"))
    }

    @Test func ongoingMigraineSaysSo() {
        let prompt = IntelligencePrompts.analysisPrompt(migraine: Migraine(startDate: Date(), painLevel: 3, stressLevel: 3), user: nil)
        #expect(prompt.contains("Duration: ongoing"))
        #expect(!prompt.contains("User:"))
    }

    @Test func explanationParsingToleratesFencesAndProse() {
        let fenced = "```json\n{\"description\": \"A\", \"recommendation\": \"B\"}\n```"
        #expect(IntelligencePrompts.parseExplanation(fenced, fallbackDescription: "x") == QuickBitExplanation(description: "A", recommendation: "B"))

        let prose = "Sure! {\"description\": \"C\", \"recommendation\": \"D\"} Hope that helps."
        #expect(IntelligencePrompts.parseExplanation(prose, fallbackDescription: "x") == QuickBitExplanation(description: "C", recommendation: "D"))

        let plain = "First line\nSecond line"
        let parsed = IntelligencePrompts.parseExplanation(plain, fallbackDescription: "x")
        #expect(parsed.description == "First line")
        #expect(parsed.recommendation == "Second line")

        let single = IntelligencePrompts.parseExplanation("Only line", fallbackDescription: "x")
        #expect(single.description == "Only line")
        #expect(!single.recommendation.isEmpty)
    }

    @Test func historyDatasetIsMostRecentFirstWithNulls() {
        let older = Migraine(startDate: Date(timeIntervalSince1970: 1_000_000), endDate: Date(timeIntervalSince1970: 1_003_600), painLevel: 4, stressLevel: 2)
        let newer = Migraine(startDate: Date(timeIntervalSince1970: 2_000_000), painLevel: 7, stressLevel: 5, triggers: [.stress])
        let dataset = IntelligencePrompts.historyDataset(migraines: [older, newer], limit: 60)

        let rows = dataset.table.components(separatedBy: "\n").dropFirst(2)
        #expect(rows.first?.contains("|7|5|Stress|0.0|") == true)
        #expect(rows.last?.contains("|4|2||1.0|") == true)
        #expect(dataset.json.contains("\"sleep_h\":null"))
        #expect(dataset.json.hasPrefix("[\n{"))
    }

    @Test func summariesCompactTheProfileAndHistory() {
        let user = User(name: "Nick", averageSleepHours: 7, averageCaffeineMg: 200, chronicConditions: ["Asthma"])
        #expect(IntelligencePrompts.summarize(user: user) == "name=Nick; avgSleep=7.0h; avgCaffeine=200mg; conditions=Asthma")
        #expect(IntelligencePrompts.summarize(user: nil).isEmpty)

        let migraines = [Migraine(startDate: Date(), painLevel: 6, stressLevel: 1, triggers: [.chocolate]), Migraine(startDate: Date(), painLevel: 8, stressLevel: 1)]
        #expect(IntelligencePrompts.summarize(migraines: migraines, limit: 50) == "count=2; recentAvgPain=7.0; commonTriggers=Chocolate")
        #expect(IntelligencePrompts.summarize(migraines: [], limit: 50).isEmpty)
    }

    @Test func serviceIsUnavailableOffDeviceAndRefusesChat() async {
        let service = IntelligenceService()
        // Foundation Models is gated to iOS/macOS 26 hardware with Apple Intelligence on.
        if !service.isAvailable {
            #expect(!service.isChatActive)
            await #expect(throws: IntelligenceError.self) { try await service.send(message: "hi") }
        }
    }
}
