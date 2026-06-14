//
//  InsightManager.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//
//  Orchestrates insight generation. All deterministic rules live in
//  Domain/InsightRules.swift; this manager owns observable state and the
//  Apple Intelligence hand-off.
//

import Foundation
import Observation
import os

@Observable
@MainActor
final class InsightManager {
    // MARK: - Dependencies
    private let userManager: UserManager
    private let migraineManager: MigraineManager
    private let weatherManager: WeatherManager
    private let healthManager: HealthManager

    // Apple Intelligence / Foundation Models orchestrator (availability-gated internally)
    let intelligenceManager: IntelligenceManager

    // MARK: - Public state
    private(set) var insights: [Insight] = []
    private(set) var isRefreshing: Bool = false
    private(set) var lastRefreshed: Date?
    private(set) var errors: [InsightError] = []

    // Cache of generated guidance per migraine
    private(set) var generatedGuidance: [UUID: String] = [:]
    // Cache AI explanations for QuickBits (by insight dedupeKey hash)
    private(set) var quickBitExplanations: [String: QuickBitExplanation] = [:]
    var isGeneratingGuidance: Bool = false
    var isGeneratingGuidanceFor: Migraine? = nil

    // MARK: - Init
    init(
        userManager: UserManager,
        migraineManager: MigraineManager,
        weatherManager: WeatherManager,
        healthManager: HealthManager
    ) {
        self.userManager = userManager
        self.migraineManager = migraineManager
        self.weatherManager = weatherManager
        self.healthManager = healthManager
        self.intelligenceManager = IntelligenceManager(userManager: userManager, migraineManager: migraineManager)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(migraineCreated(_:)),
            name: MigraineManager.migraineCreatedNotification,
            object: migraineManager
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: MigraineManager.migraineCreatedNotification,
            object: migraineManager
        )
    }

    @objc private func migraineCreated(_ note: Notification) {
        guard let m = note.userInfo?["migraine"] as? Migraine else { return }
        Task { await self.handleJustCreatedMigraine(m) }
    }

    func handleJustCreatedMigraine(_ migraine: Migraine) async {
        guard intelligenceManager.supportsAppleIntelligence else { return }
        if let existing = migraine.insight, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            migraine.insight = nil
        }
        await analyzeNewlyCreatedMigraine(migraine)
    }

    // MARK: - Refresh orchestration
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errors.removeAll()

        let all = InsightRules.generateAll(from: migraineManager.migraines)
        insights = all.sorted(by: Insight.sorter)
        lastRefreshed = Date()

        isRefreshing = false
    }

    // MARK: - Intelligence

    func analyzeNewlyCreatedMigraine(_ migraine: Migraine) async {
        guard intelligenceManager.supportsAppleIntelligence else {
            errors.append(.intelligenceUnavailable)
            return
        }
        guard !isGeneratingGuidance else { return }
        isGeneratingGuidance = true
        isGeneratingGuidanceFor = migraine
        defer {
            isGeneratingGuidance = false
            isGeneratingGuidanceFor = nil
        }

        let user = userManager.currentUser
        do {
            if #available(iOS 26.0, *) {
                if let text = try await intelligenceManager.analyze(migraine: migraine, user: user) {
                    migraineManager.update(migraine) { m in
                        m.insight = text
                    }
                    generatedGuidance[migraine.id] = text
                    let card = Insight(
                        category: .generative,
                        title: String(localized: "Migraine explanation"),
                        message: text,
                        priority: .medium,
                        tags: ["migraineID": migraine.id]
                    )
                    insights.insert(card, at: 0)
                }
            }
        } catch {
            errors.append(.intelligenceAnalysisFailed(underlying: error))
        }
    }

    func startCounselorChat() async {
        guard intelligenceManager.supportsAppleIntelligence else {
            errors.append(.intelligenceUnavailable)
            return
        }
        let all = migraineManager.migraines
        let user = userManager.currentUser
        if #available(iOS 26.0, *) {
            await intelligenceManager.startChat(migraines: all, user: user)
        }
    }

    @available(iOS 26.0, *)
    func sendCounselorMessage(_ text: String) async -> String {
        guard intelligenceManager.supportsAppleIntelligence else {
            errors.append(.intelligenceUnavailable)
            return String(localized: "This device does not support Apple Intelligence.")
        }
        do {
            self.isGeneratingGuidance = true
            defer { self.isGeneratingGuidance = false }
            return try await intelligenceManager.send(message: text)
        } catch {
            errors.append(.chatSendFailed(underlying: error))
            return String(localized: "Sorry, I ran into a problem.")
        }
    }

    func resetCounselorChat() {
        intelligenceManager.resetChat()
    }

    // MARK: - QuickBit explanations
    @available(iOS 26.0, *)
    func explanation(for insight: Insight) async -> QuickBitExplanation? {
        guard intelligenceManager.supportsAppleIntelligence else { return nil }
        let key = insight.dedupeKey.key
        if let cached = quickBitExplanations[key] { return cached }
        do {
            let user = userManager.currentUser
            if let exp = try await intelligenceManager.explain(insight: insight, user: user) {
                quickBitExplanations[key] = exp
                return exp
            }
        } catch {
            errors.append(.intelligenceAnalysisFailed(underlying: error))
        }
        return nil
    }
}
