//
//  IntelligenceManager.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import Foundation
import Observation
import WeatherKit
import FoundationModels

// Note: Foundation Models APIs are available on iOS/iPadOS 18 (SDK 26), macOS 15 Sequoia and later.
// Consult Apple’s Foundation Models framework documentation for the latest types and usage patterns.
// This manager is written to compile on older OS versions by guarding all AI calls with @available checks.

@Observable
@MainActor
final class IntelligenceManager {

    // MARK: - Dependencies
    private let userManager: UserManager
    private let migraineManager: MigraineManager

    // MARK: - Chat state (ephemeral)
    private(set) var conversation: [ChatMessage] = []
    private(set) var isChatActive: Bool = false
    private var chatSessionBox: AnyObject?  // Holds LanguageModelSession on supported OS versions

    // MARK: - Init
    init(userManager: UserManager, migraineManager: MigraineManager) {
        self.userManager = userManager
        self.migraineManager = migraineManager
    }

    // MARK: - Capability

    var supportsAppleIntelligence: Bool {
        if #available(iOS 26.0, macOS 26.0, *) {
            // Check whether the on-device system language model is available (Apple Intelligence enabled & ready)
            return SystemLanguageModel.default.isAvailable
        } else {
            return false
        }
    }

    // MARK: - Feature 1: Single-migraine analysis

    /// Uses Apple Intelligence (Foundation Models) to produce a concise, user-facing explanation
    /// of likely contributing factors from the given migraine’s properties.
    @available(iOS 26.0, *)
    func analyze(migraine: Migraine, user: User?) async throws -> String? {
        guard supportsAppleIntelligence else { return nil }
        let prompt = buildSingleMigrainePrompt(migraine: migraine, user: user)

        // Build instructions to shape the assistant's tone and task
        let instructions = """
        You are a data analyst for health logs.
        Provide a concise explanation of likely contributing factors for this single migraine event based ONLY on the provided fields.
        Then offer up to two non-clinical, everyday mitigation ideas tied to those factors (e.g., hydration, sleep regularity, screen breaks, balanced meals, stress-reduction techniques, indoor air/lighting adjustments).
        Do NOT provide medical diagnoses, prescriptions, or treatment plans. Use conditional, non-prescriptive language (e.g., "you could try", "might help").
        Keep it to 2–4 sentences, neutral and practical.
        End with: "This is general, non-medical guidance and not a diagnosis."
        """

        // Create a fresh on-device session and ask for a response
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return response.content
    }

    // MARK: - Feature 2: Counselor chat

    /// Seeds a chat session with compact summaries of the user and migraine history.
    @available(iOS 26.0, *)
    func startChat(migraines: [Migraine], user: User?) async {
        guard supportsAppleIntelligence else { return }
        conversation.removeAll()

        // System prompt to set behavior
        conversation.append(.system("""
        You are a data analyst focused on migraine log trends. Provide descriptive, evidence-informed pattern analysis.
        Stay strictly non-medical: do NOT give advice, diagnoses, or treatment suggestions.
        Encourage the user to consult a clinician for persistent or severe issues.
        """))

        // You can optionally compress the history more:
        let userSummary = summarize(user: user)
        let historySummary = summarize(migraines: migraines, limit: 50)

        // Provide a compact, structured dataset (most recent first)
        let (entriesTable, entriesJSON) = buildHistoryDataset(migraines: migraines, user: user, limit: 60)
        conversation.append(.system("Entries (most recent first):\n\(entriesTable)"))
        conversation.append(.system("EntriesJSON:\n\(entriesJSON)"))

        if !userSummary.isEmpty {
            conversation.append(.system("User profile: \(userSummary)"))
        }
        if !historySummary.isEmpty {
            conversation.append(.system("Migraine history summary: \(historySummary)"))
        }

        conversation.append(.assistant("I’ve loaded your migraine history and profile, including your last \(min(migraines.count, 60)) entries. I can analyze patterns and trends in your logs. What would you like to explore?"))

        var instructions = """
        You are a data analyst for migraine logs. Be neutral, concise, and purely descriptive.
        Use the user's profile and migraine history only to identify trends, correlations, and patterns.
        You are provided with two views of the data: a Markdown table (Entries) and a JSON array (EntriesJSON).
        When the user asks whether a pattern appears "in my entries," reference specific rows by date or fields from Entries/EntriesJSON.
        Prefer concrete, data-backed statements over generalities. If the data is insufficient, say what additional fields would help.
        Do NOT provide concrete medical advice, diagnoses, or treatment suggestions, though you can state the obvious.
        """
        if !userSummary.isEmpty {
            instructions += "\nUser profile: \(userSummary)"
        }
        if !historySummary.isEmpty {
            instructions += "\nMigraine history summary: \(historySummary)"
        }
        // Initialize/replace the session to begin a new multi-turn chat context
        chatSessionBox = LanguageModelSession(instructions: instructions)
    }

    /// Sends a user message and returns the assistant reply using Apple Intelligence.
    @available(iOS 26.0, *)
    func send(message: String) async throws -> String {
        guard supportsAppleIntelligence else { return "Apple Intelligence is not available on this device." }
        guard isChatActive else {
            return "Chat session is not active. Please start a new analysis chat."
        }

        conversation.append(.user(message))
        guard let session = chatSessionBox as? LanguageModelSession else {
            let reply = "Chat session is not active. Please start a new analysis chat."
            conversation.append(.assistant(reply))
            return reply
        }
        let response = try await session.respond(to: message)
        let reply = response.content
        conversation.append(.assistant(reply))
        return reply
    }

    /// Clears the chat state.
    func resetChat() {
        chatSessionBox = nil
        conversation.removeAll()
        isChatActive = false
    }

    // MARK: - Prompt builders

    private func buildSingleMigrainePrompt(migraine: Migraine, user: User?) -> String {
        var lines: [String] = []
        lines.append("Task: Provide a concise analysis of likely contributing factors for this single migraine event. Then include up to two non-clinical mitigation ideas tied to those factors. Do NOT provide medical diagnoses, prescriptions, or treatment plans.")
        lines.append("Avoid medical advice/diagnoses. Use conditional, non-prescriptive language. 2–4 sentences max.")
        if let name = (user?.name.isEmpty == false ? user?.name : nil) {
            lines.append("User: \(name)")
        }
        lines.append("Pain: \(migraine.painLevel)/10, Stress: \(migraine.stressLevel)/10")
        if let end = migraine.endDate {
            let hours = max(0, end.timeIntervalSince(migraine.startDate)) / 3600.0
            lines.append(String(format: "Duration: %.1f hours", hours))
        } else {
            lines.append("Duration: ongoing")
        }

        // Triggers: include both canonical and custom
        let canonical = migraine.triggers.map(\.displayName)
        let custom = migraine.customTriggers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let allTriggers = LinkedHashSet(elements: canonical + custom, key: { $0.lowercased() }).ordered
        if !allTriggers.isEmpty {
            lines.append("Selected triggers: \(allTriggers.joined(separator: ", "))")
        }

        if !migraine.foodsEaten.isEmpty {
            lines.append("Foods: \(migraine.foodsEaten.joined(separator: ", "))")
        }
        if let h = migraine.health {
            var healthBits: [String] = []
            if let w = h.waterLiters { healthBits.append(String(format: "water=%.1fL", w)) }
            if let s = h.sleepHours { healthBits.append(String(format: "sleep=%.1fh", s)) }
            if let kcal = h.energyKilocalories { healthBits.append(String(format: "calories=%.0f kcal", kcal)) }
            if let caf = h.caffeineMg { healthBits.append(String(format: "caffeine=%.0f mg", caf)) }
            if !healthBits.isEmpty { lines.append("Health: " + healthBits.joined(separator: ", ")) }
        }
        if let w = migraine.weather {
            lines.append(String(format: "Weather: %.0f hPa, %.0f%% humidity, %.0f°C, condition=%@",
                                w.barometricPressureHpa, w.humidityPercent, w.temperatureCelsius, w.condition.description))
        }
        if let note = migraine.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Note: \(note)")
        }
        lines.append("Output: A short summary of likely contributing factors plus up to two non-clinical mitigation ideas linked to those factors. End with: This is general, non-medical guidance and not a diagnosis.")
        return lines.joined(separator: "\n")
    }

    /// Builds a compact Markdown table and a JSON array string for recent migraines.
    /// Keeps fields minimal to reduce token use but sufficient for trend questions.
    private func buildHistoryDataset(migraines: [Migraine], user: User?, limit: Int) -> (table: String, json: String) {
        let slice = migraines.sorted(by: { $0.startDate > $1.startDate }).prefix(limit)
        // Markdown table header
        var tableLines: [String] = [
            "| date | pain | stress | triggers | duration_h | sleep_h | caffeine_mg | pressure_hPa | humidity_% | temp_C |",
            "|------|------|--------|----------|------------|---------|-------------|--------------|------------|--------|"
        ]
        // JSON array
        var jsonItems: [String] = []
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        for m in slice {
            let dateStr = df.string(from: m.startDate)
            let pain = m.painLevel
            let stress = m.stressLevel
            let trig = (m.triggers.map(\.displayName) + m.customTriggers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
                .joined(separator: "; ")
            let durH: Double = {
                if let end = m.endDate { return max(0, end.timeIntervalSince(m.startDate)) / 3600.0 }
                return 0
            }()
            var sleepH: String = ""
            var cafMg: String = ""
            if let h = m.health {
                if let s = h.sleepHours { sleepH = String(format: "%.1f", s) }
                if let c = h.caffeineMg { cafMg = String(format: "%.0f", c) }
            }
            var pStr = "", humStr = "", tStr = ""
            if let w = m.weather {
                pStr = String(format: "%.0f", w.barometricPressureHpa)
                humStr = String(format: "%.0f", w.humidityPercent)
                tStr = String(format: "%.0f", w.temperatureCelsius)
            }
            tableLines.append("|\(dateStr)|\(pain)|\(stress)|\(trig)|\(String(format: "%.1f", durH))|\(sleepH)|\(cafMg)|\(pStr)|\(humStr)|\(tStr)|")
            // JSON item (manually build to avoid additional encoders)
            let jsonItem = """
            {"date":"\(dateStr)","pain":\(pain),"stress":\(stress),"triggers":"\(trig)","duration_h":\(String(format: "%.1f", durH)),"sleep_h":\(sleepH.isEmpty ? "null" : sleepH),"caffeine_mg":\(cafMg.isEmpty ? "null" : cafMg),"pressure_hPa":\(pStr.isEmpty ? "null" : pStr),"humidity_pct":\(humStr.isEmpty ? "null" : humStr),"temp_C":\(tStr.isEmpty ? "null" : tStr)}
            """
            jsonItems.append(jsonItem)
        }
        let table = tableLines.joined(separator: "\n")
        let json = "[\n" + jsonItems.joined(separator: ",\n") + "\n]"
        return (table, json)
    }

    private func summarize(user: User?) -> String {
        guard let u = user else { return "" }
        var parts: [String] = []
        if !u.name.isEmpty { parts.append("name=\(u.name)") }
        parts.append(String(format: "avgSleep=%.1fh", u.averageSleepHours))
        parts.append("avgCaffeine=\(Int(u.averageCaffeineMg))mg")
        if !u.chronicConditions.isEmpty {
            parts.append("conditions=\(u.chronicConditions.joined(separator: ", "))")
        }
        if !u.dietaryRestrictions.isEmpty {
            parts.append("dietary=\(u.dietaryRestrictions.joined(separator: ", "))")
        }
        return parts.joined(separator: "; ")
    }

    private func summarize(migraines: [Migraine], limit: Int) -> String {
        if migraines.isEmpty { return "" }
        let top = migraines.prefix(limit)
        let total = migraines.count
        let avgPain = Double(top.reduce(0) { $0 + $1.painLevel }) / Double(top.count)
        let triggersFlat = Array(Set(top.flatMap { $0.triggers.map(\.displayName) })).prefix(10)
        return "count=\(total); recentAvgPain=\(String(format: "%.1f", avgPain)); commonTriggers=\(triggersFlat.joined(separator: ", "))"
    }
}

