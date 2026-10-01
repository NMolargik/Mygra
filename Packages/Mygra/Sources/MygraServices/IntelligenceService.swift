//
//  IntelligenceService.swift
//  MygraServices
//
//  Apple Intelligence (Foundation Models, iOS 26+) behind the Core `MigraineIntelligence`
//  seam: single-migraine analysis, Quick Bit explanations, and the multi-turn analyst
//  chat. Every model call is availability-gated so the module compiles for the iOS 18
//  floor; prompts are built by pure helpers that are host-tested.
//

import Foundation
import Observation
import MygraCore
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

nonisolated public enum IntelligenceError: LocalizedError {
    case unavailable
    case chatInactive

    public var errorDescription: String? {
        switch self {
        case .unavailable: return String(localized: "Apple Intelligence is not available on this device.")
        case .chatInactive: return String(localized: "Chat session is not active. Please start a new analysis chat.")
        }
    }
}

@MainActor
@Observable
public final class IntelligenceService: MigraineIntelligence {

    public private(set) var conversation: [ChatMessage] = []
    public private(set) var isChatActive: Bool = false

    /// Holds a `LanguageModelSession` on supported OS versions.
    @ObservationIgnored private var chatSession: AnyObject?

    public init() {}

    public var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    // MARK: - Single-migraine analysis

    public func analyze(migraine: Migraine, user: User?) async throws -> String? {
        #if canImport(FoundationModels)
        guard isAvailable else { return nil }
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(instructions: IntelligencePrompts.analysisInstructions)
            let response = try await session.respond(to: IntelligencePrompts.analysisPrompt(migraine: migraine, user: user))
            return response.content
        }
        #endif
        return nil
    }

    // MARK: - Quick Bit explanation

    public func explain(insight: Insight, user: User?) async throws -> QuickBitExplanation? {
        #if canImport(FoundationModels)
        guard isAvailable else { return nil }
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(instructions: IntelligencePrompts.explanationInstructions)
            let response = try await session.respond(to: IntelligencePrompts.explanationPrompt(insight: insight, user: user))
            return IntelligencePrompts.parseExplanation(response.content, fallbackDescription: insight.message)
        }
        #endif
        return nil
    }

    // MARK: - Analyst chat

    public func startChat(migraines: [Migraine], user: User?) async {
        guard isAvailable else { return }
        conversation.removeAll()

        let userSummary = IntelligencePrompts.summarize(user: user)
        let historySummary = IntelligencePrompts.summarize(migraines: migraines, limit: 50)
        let dataset = IntelligencePrompts.historyDataset(migraines: migraines, limit: 60)

        conversation.append(.system(IntelligencePrompts.chatSystemPrompt))
        conversation.append(.system("Entries (most recent first):\n\(dataset.table)"))
        conversation.append(.system("EntriesJSON:\n\(dataset.json)"))
        if !userSummary.isEmpty { conversation.append(.system("User profile: \(userSummary)")) }
        if !historySummary.isEmpty { conversation.append(.system("Migraine history summary: \(historySummary)")) }
        conversation.append(.assistant(IntelligencePrompts.chatGreeting(entryCount: min(migraines.count, 60))))

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            chatSession = LanguageModelSession(instructions: IntelligencePrompts.chatInstructions(userSummary: userSummary, historySummary: historySummary))
            isChatActive = true
        }
        #endif
    }

    public func send(message: String) async throws -> String {
        guard isAvailable else { throw IntelligenceError.unavailable }
        guard isChatActive else { throw IntelligenceError.chatInactive }
        conversation.append(.user(message))

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), let session = chatSession as? LanguageModelSession {
            let reply = try await session.respond(to: message).content
            conversation.append(.assistant(reply))
            return reply
        }
        #endif
        throw IntelligenceError.chatInactive
    }

    public func resetChat() {
        chatSession = nil
        conversation.removeAll()
        isChatActive = false
    }
}

// MARK: - Prompts (pure)

public enum IntelligencePrompts {

    public static let analysisInstructions = """
    You are a data analyst for health logs.
    Provide a concise explanation of likely contributing factors for this single migraine event based ONLY on the provided fields.
    Then offer up to two non-clinical, everyday mitigation ideas tied to those factors (e.g., hydration, sleep regularity, screen breaks, balanced meals, stress-reduction techniques, indoor air/lighting adjustments).
    Do NOT provide medical diagnoses, prescriptions, or treatment plans. Use conditional, non-prescriptive language (e.g., "you could try", "might help").
    Keep it to 2–4 sentences, neutral and practical.
    End with: "This is general, non-medical guidance and not a diagnosis."
    """

    public static let explanationInstructions = """
    You are a clear, neutral explainer for health logging insights.
    Based only on the provided fields, write:
    1) a brief, 1-2 sentence description explaining the insight in everyday terms, and
    2) one practical, non-medical recommendation relevant to this insight.
    Avoid medical diagnoses or treatment advice. Keep tone supportive and neutral.
    Output strictly as JSON with keys: {"description": string, "recommendation": string}. Do not wrap in markdown code fences; return only the JSON object.
    """

    public static let chatSystemPrompt = """
    You are a data analyst focused on migraine log trends. Provide descriptive, evidence-informed pattern analysis.
    Stay strictly non-medical: do NOT give advice, diagnoses, or treatment suggestions.
    Encourage the user to consult a clinician for persistent or severe issues.
    """

    public static func chatInstructions(userSummary: String, historySummary: String) -> String {
        var instructions = """
        You are a data analyst for migraine logs. Be neutral, concise, and purely descriptive.
        Use the user's profile and migraine history only to identify trends, correlations, and patterns.
        You are provided with two views of the data: a Markdown table (Entries) and a JSON array (EntriesJSON).
        When the user asks whether a pattern appears "in my entries," reference specific rows by date or fields from Entries/EntriesJSON.
        Prefer concrete, data-backed statements over generalities. If the data is insufficient, say what additional fields would help.
        Do NOT provide concrete medical advice, diagnoses, or treatment suggestions, though you can state the obvious.
        Return all responses in natural language with no special data wrapping. Give detailed responses.
        """
        if !userSummary.isEmpty { instructions += "\nUser profile: \(userSummary)" }
        if !historySummary.isEmpty { instructions += "\nMigraine history summary: \(historySummary)" }
        return instructions
    }

    public static func chatGreeting(entryCount: Int) -> String {
        String(localized: "I’ve loaded your migraine history and profile, including your last \(entryCount) entries. I can analyze patterns and trends in your logs. What would you like to explore?")
    }

    public static func analysisPrompt(migraine: Migraine, user: User?) -> String {
        var lines: [String] = []
        lines.append("Task: Provide a concise analysis of likely contributing factors for this single migraine event. Then include up to two non-clinical mitigation ideas tied to those factors. Do NOT provide medical diagnoses, prescriptions, or treatment plans.")
        lines.append("Avoid medical advice/diagnoses. Use conditional, non-prescriptive language. 2–4 sentences max.")
        if let name = user?.name, !name.isEmpty {
            lines.append("User: \(name)")
        }
        lines.append("Pain: \(migraine.painLevel)/10, Stress: \(migraine.stressLevel)/10")
        if let end = migraine.endDate {
            let hours = max(0, end.timeIntervalSince(migraine.startDate)) / 3600.0
            lines.append(String(format: "Duration: %.1f hours", hours))
        } else {
            lines.append("Duration: ongoing")
        }
        let triggers = migraine.allTriggerNames
        if !triggers.isEmpty {
            lines.append("Selected triggers: \(triggers.joined(separator: ", "))")
        }
        if !migraine.foodsEaten.isEmpty {
            lines.append("Foods: \(migraine.foodsEaten.joined(separator: ", "))")
        }
        if let health = migraine.health {
            var bits: [String] = []
            if let water = health.waterLiters { bits.append(String(format: "water=%.1fL", water)) }
            if let sleep = health.sleepHours { bits.append(String(format: "sleep=%.1fh", sleep)) }
            if let kcal = health.energyKilocalories { bits.append(String(format: "calories=%.0f kcal", kcal)) }
            if let caffeine = health.caffeineMg { bits.append(String(format: "caffeine=%.0f mg", caffeine)) }
            if !bits.isEmpty { lines.append("Health: " + bits.joined(separator: ", ")) }
        }
        if let weather = migraine.weather {
            lines.append(String(format: "Weather: %.0f hPa, %.0f%% humidity, %.0f°C, condition=%@",
                                weather.barometricPressureHpa, weather.humidityPercent, weather.temperatureCelsius, weather.condition.rawValue))
        }
        if let note = migraine.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Note: \(note)")
        }
        lines.append("Output: A short summary of likely contributing factors plus up to two non-clinical mitigation ideas linked to those factors. End with: This is general, non-medical guidance and not a diagnosis.")
        return lines.joined(separator: "\n")
    }

    public static func explanationPrompt(insight: Insight, user: User?) -> String {
        var lines: [String] = []
        lines.append("Task: Explain this insight in everyday terms and provide one non-medical recommendation.")
        if let name = user?.name, !name.isEmpty {
            lines.append("User: \(name)")
        }
        lines.append("Insight category: \(insight.category.rawValue)")
        lines.append("Title: \(insight.title)")
        if !insight.message.isEmpty {
            lines.append("Message: \(insight.message)")
        }
        if !insight.tags.isEmpty {
            let tags = insight.tags.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; ")
            lines.append("Tags: \(tags)")
        }
        lines.append("Priority: \(insight.priority.rawValue)")
        lines.append("Output: JSON with keys {description, recommendation} only.")
        return lines.joined(separator: "\n")
    }

    /// Decodes the model's JSON (tolerating code fences and surrounding prose), falling
    /// back to a heuristic split of plain text.
    public static func parseExplanation(_ raw: String, fallbackDescription: String) -> QuickBitExplanation {
        let cleaned = extractJSON(from: raw) ?? raw
        if let decoded = try? JSONDecoder().decode(QuickBitExplanation.self, from: Data(cleaned.utf8)) {
            return decoded
        }
        let parts = raw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let description = parts.first ?? fallbackDescription
        let recommendation = parts.dropFirst().joined(separator: " ")
        return QuickBitExplanation(
            description: description,
            recommendation: recommendation.isEmpty
                ? String(localized: "Consider small, everyday adjustments like hydration, sleep regularity, and balanced meals.")
                : recommendation
        )
    }

    static func extractJSON(from text: String) -> String? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let newline = s.range(of: "\n") {
                s.removeSubrange(s.startIndex..<newline.upperBound)
            }
            if let fence = s.range(of: "```", options: .backwards) {
                s.removeSubrange(fence.lowerBound..<s.endIndex)
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}"), first <= last {
            return String(s[first...last])
        }
        return nil
    }

    /// A compact Markdown table and JSON array of recent migraines (most recent first).
    public static func historyDataset(migraines: [Migraine], limit: Int) -> (table: String, json: String) {
        let slice = migraines.sorted { $0.startDate > $1.startDate }.prefix(limit)
        var tableLines: [String] = [
            "| date | pain | stress | triggers | duration_h | sleep_h | caffeine_mg | pressure_hPa | humidity_% | temp_C |",
            "|------|------|--------|----------|------------|---------|-------------|--------------|------------|--------|",
        ]
        var jsonItems: [String] = []
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        for migraine in slice {
            let date = formatter.string(from: migraine.startDate)
            let triggers = migraine.allTriggerNames.joined(separator: "; ")
            let durationHours: Double = migraine.endDate.map { max(0, $0.timeIntervalSince(migraine.startDate)) / 3600.0 } ?? 0
            let sleep = migraine.health?.sleepHours.map { String(format: "%.1f", $0) } ?? ""
            let caffeine = migraine.health?.caffeineMg.map { String(format: "%.0f", $0) } ?? ""
            let pressure = migraine.weather.map { String(format: "%.0f", $0.barometricPressureHpa) } ?? ""
            let humidity = migraine.weather.map { String(format: "%.0f", $0.humidityPercent) } ?? ""
            let temperature = migraine.weather.map { String(format: "%.0f", $0.temperatureCelsius) } ?? ""

            tableLines.append("|\(date)|\(migraine.painLevel)|\(migraine.stressLevel)|\(triggers)|\(String(format: "%.1f", durationHours))|\(sleep)|\(caffeine)|\(pressure)|\(humidity)|\(temperature)|")
            jsonItems.append(
                "{\"date\":\"\(date)\",\"pain\":\(migraine.painLevel),\"stress\":\(migraine.stressLevel),\"triggers\":\"\(triggers)\",\"duration_h\":\(String(format: "%.1f", durationHours)),\"sleep_h\":\(sleep.isEmpty ? "null" : sleep),\"caffeine_mg\":\(caffeine.isEmpty ? "null" : caffeine),\"pressure_hPa\":\(pressure.isEmpty ? "null" : pressure),\"humidity_pct\":\(humidity.isEmpty ? "null" : humidity),\"temp_C\":\(temperature.isEmpty ? "null" : temperature)}"
            )
        }
        return (tableLines.joined(separator: "\n"), "[\n" + jsonItems.joined(separator: ",\n") + "\n]")
    }

    public static func summarize(user: User?) -> String {
        guard let user else { return "" }
        var parts: [String] = []
        if !user.name.isEmpty { parts.append("name=\(user.name)") }
        parts.append(String(format: "avgSleep=%.1fh", user.averageSleepHours))
        parts.append("avgCaffeine=\(Int(user.averageCaffeineMg))mg")
        if !user.chronicConditions.isEmpty { parts.append("conditions=\(user.chronicConditions.joined(separator: ", "))") }
        if !user.dietaryRestrictions.isEmpty { parts.append("dietary=\(user.dietaryRestrictions.joined(separator: ", "))") }
        return parts.joined(separator: "; ")
    }

    public static func summarize(migraines: [Migraine], limit: Int) -> String {
        guard !migraines.isEmpty else { return "" }
        let top = migraines.prefix(limit)
        let avgPain = Double(top.reduce(0) { $0 + $1.painLevel }) / Double(top.count)
        let triggers = Array(Set(top.flatMap { $0.triggers.map(\.displayName) })).sorted().prefix(10)
        return "count=\(migraines.count); recentAvgPain=\(String(format: "%.1f", avgPain)); commonTriggers=\(triggers.joined(separator: ", "))"
    }
}
