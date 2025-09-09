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
    private var chatSession: LanguageModelSession?  // Maintains multi-turn context

    // MARK: - Init
    init(userManager: UserManager, migraineManager: MigraineManager) {
        self.userManager = userManager
        self.migraineManager = migraineManager
    }

    // MARK: - Capability

    var supportsAppleIntelligence: Bool {
        if #available(iOS 18.0, macOS 15.0, *) {
            // Check whether the on-device system language model is available (Apple Intelligence enabled & ready)
            return SystemLanguageModel.default.isAvailable
        } else {
            return false
        }
    }

    // MARK: - Feature 1: Single-migraine analysis

    /// Uses Apple Intelligence (Foundation Models) to produce a concise, user-facing explanation
    /// of likely contributing factors from the given migraine’s properties.
    func analyze(migraine: Migraine, user: User?) async throws -> String? {
        guard supportsAppleIntelligence else { return nil }
        let prompt = buildSingleMigrainePrompt(migraine: migraine, user: user)

        if #available(iOS 18.0, macOS 15.0, *) {
            // Build instructions to shape the assistant's tone and task
            let instructions = """
            You are an empathetic migraine assistant.
            Analyze the provided migraine entry and briefly explain likely contributing factors
            and one practical tip for prevention or relief. Be concise (2–4 sentences) and avoid
            medical diagnoses.
            """

            // Create a fresh on-device session and ask for a response
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content
        } else {
            return nil
        }
    }

    // MARK: - Feature 2: Counselor chat

    /// Seeds a chat session with compact summaries of the user and migraine history.
    func startChat(migraines: [Migraine], user: User?) async {
        guard supportsAppleIntelligence else { return }
        conversation.removeAll()

        // System prompt to set behavior
        conversation.append(.system("""
        You are an empathetic, evidence-informed migraine counselor. Be concise, practical, and supportive.
        Use information provided about the user and their migraine history to personalize guidance.
        Avoid making medical diagnoses. Encourage consulting a clinician for persistent or severe issues.
        """))

        // Context messages: compact summaries
        conversation.append(.assistant("I’ve loaded your migraine history and profile. How can I help today?"))

        // You can optionally compress the history more:
        let userSummary = summarize(user: user)
        let historySummary = summarize(migraines: migraines, limit: 50)
        if !userSummary.isEmpty {
            conversation.append(.system("User profile: \(userSummary)"))
        }
        if !historySummary.isEmpty {
            conversation.append(.system("Migraine history summary: \(historySummary)"))
        }

        if #available(iOS 18.0, macOS 15.0, *) {
            var instructions = """
            You are a knowledgeable, friendly migraine counselor AI. Be empathetic, practical, and concise.
            Use the user's profile and migraine history to personalize guidance. Avoid medical diagnoses;
            encourage consulting a clinician for persistent or severe issues.
            """
            if !userSummary.isEmpty {
                instructions += "\nUser profile: \(userSummary)"
            }
            if !historySummary.isEmpty {
                instructions += "\nMigraine history summary: \(historySummary)"
            }
            // Initialize/replace the session to begin a new multi-turn chat context
            chatSession = LanguageModelSession(instructions: instructions)
        }

        isChatActive = true
    }

    /// Sends a user message and returns the assistant reply using Apple Intelligence.
    func send(message: String) async throws -> String {
        guard supportsAppleIntelligence else { return "Apple Intelligence is not available on this device." }
        guard isChatActive else {
            return "Chat session is not active. Please start a new counselor chat."
        }

        conversation.append(.user(message))

        if #available(iOS 18.0, macOS 15.0, *) {
            guard let session = chatSession else {
                let reply = "Chat session is not active. Please start a new counselor chat."
                conversation.append(.assistant(reply))
                return reply
            }
            let response = try await session.respond(to: message)
            let reply = response.content
            conversation.append(.assistant(reply))
            return reply
        } else {
            return "Apple Intelligence is not available on this device."
        }
    }

    /// Clears the chat state.
    func resetChat() {
        chatSession = nil
        conversation.removeAll()
        isChatActive = false
    }

    // MARK: - Prompt builders

    private func buildSingleMigrainePrompt(migraine: Migraine, user: User?) -> String {
        var lines: [String] = []
        lines.append("Task: Provide a concise, empathetic explanation of likely contributing factors for this migraine.")
        lines.append("Avoid medical diagnoses. Use simple language. 2–4 sentences.")
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
        lines.append("Output: A short explanation of likely contributing factors and one practical tip.")
        return lines.joined(separator: "\n")
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

// MARK: - ChatMessage

enum ChatRole: String {
    case system, user, assistant
}

struct ChatMessage: Hashable {
    let role: ChatRole
    let content: String

    static func system(_ text: String) -> ChatMessage { .init(role: .system, content: text) }
    static func user(_ text: String) -> ChatMessage { .init(role: .user, content: text) }
    static func assistant(_ text: String) -> ChatMessage { .init(role: .assistant, content: text) }
}

// MARK: - Small helper for stable, case-insensitive deduping while preserving order
fileprivate struct LinkedHashSet<Element, Key: Hashable> {
    private var orderedStorage: [Element] = []
    private var seenKeys: Set<Key> = []

    init<S: Sequence>(elements: S, key: (Element) -> Key) where S.Element == Element {
        for e in elements {
            let k = key(e)
            if seenKeys.insert(k).inserted {
                orderedStorage.append(e)
            }
        }
    }

    var ordered: [Element] { orderedStorage }
}
