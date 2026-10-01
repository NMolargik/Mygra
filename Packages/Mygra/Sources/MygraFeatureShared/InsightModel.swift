//
//  InsightModel.swift
//  MygraFeatureShared
//
//  The environment-injected insight surface (successor to InsightManager +
//  IntelligenceManager): rule-based Quick Bits from `InsightRules`, and the Apple
//  Intelligence hand-offs (per-migraine analysis on log, Quick Bit explanations, and
//  the analyst chat) through the `MigraineIntelligence` seam. Re-checks on every
//  change-stream event; a `migraineLogged` payload triggers analysis of that record.
//

import Foundation
import Observation
import MygraCore
import os

@MainActor
@Observable
public final class InsightModel {

    // MARK: - Dependencies

    @ObservationIgnored private let loadMigraines: any LoadMigraines
    @ObservationIgnored private let findMigraine: any FindMigraine
    @ObservationIgnored private let loadUser: any LoadUser
    @ObservationIgnored private let updateMigraine: any UpdateMigraine
    @ObservationIgnored private let observeChanges: any ObserveMigraineChanges
    @ObservationIgnored public let intelligence: any MigraineIntelligence

    // MARK: - State

    public private(set) var insights: [Insight] = []
    public private(set) var isRefreshing = false
    public private(set) var lastRefreshed: Date?
    public private(set) var errors: [IntelligenceFailure] = []

    /// Guidance generated per migraine this session.
    public private(set) var generatedGuidance: [UUID: String] = [:]
    /// Explanations cached per Quick Bit key.
    public private(set) var quickBitExplanations: [String: QuickBitExplanation] = [:]
    public private(set) var isGeneratingGuidance = false
    public private(set) var generatingGuidanceForID: UUID?
    public private(set) var isSending = false

    @ObservationIgnored private var observationTask: Task<Void, Never>?

    /// Whether Apple Intelligence can be used on this device right now.
    public var supportsAppleIntelligence: Bool { intelligence.isAvailable }
    public var conversation: [ChatMessage] { intelligence.conversation }
    public var isChatActive: Bool { intelligence.isChatActive }

    // MARK: - Init

    public init(
        loadMigraines: any LoadMigraines,
        findMigraine: any FindMigraine,
        loadUser: any LoadUser,
        updateMigraine: any UpdateMigraine,
        observeChanges: any ObserveMigraineChanges,
        intelligence: any MigraineIntelligence
    ) {
        self.loadMigraines = loadMigraines
        self.findMigraine = findMigraine
        self.loadUser = loadUser
        self.updateMigraine = updateMigraine
        self.observeChanges = observeChanges
        self.intelligence = intelligence
        startObserving()
    }

    deinit {
        observationTask?.cancel()
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            guard let stream = self?.observeChanges() else { return }
            for await change in stream {
                guard let self else { return }
                if case .migraineLogged(let id) = change, let migraine = try? self.findMigraine(withID: id) {
                    await self.analyzeNewlyLogged(migraine)
                }
                self.refresh()
            }
        }
    }

    // MARK: - Quick Bits

    /// Regenerates the rule-based insights from the store.
    public func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            // Generated explanations stay pinned above the rule-based cards.
            let generative = insights.filter { $0.category == .generative }
            let rules = InsightRules.generateAll(from: try loadMigraines()).sorted(by: Insight.sorter)
            insights = (generative + rules).uniqued(by: \.dedupeKey)
            lastRefreshed = Date()
        } catch {
            Log.insights.error("Insight refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Per-migraine analysis

    /// Generates (or regenerates) the migraine's stored insight when Apple Intelligence
    /// is available. No-op otherwise.
    public func analyzeNewlyLogged(_ migraine: Migraine) async {
        guard supportsAppleIntelligence else { return }
        guard !isGeneratingGuidance else { return }
        isGeneratingGuidance = true
        generatingGuidanceForID = migraine.id
        defer {
            isGeneratingGuidance = false
            generatingGuidanceForID = nil
        }

        let user = try? loadUser()
        do {
            guard let text = try await intelligence.analyze(migraine: migraine, user: user) else { return }
            try updateMigraine(migraine) { $0.insight = text }
            generatedGuidance[migraine.id] = text
            let card = Insight(
                category: .generative,
                title: String(localized: "Migraine explanation"),
                message: text,
                priority: .medium,
                tags: ["migraineID": migraine.id]
            )
            insights.insert(card, at: 0)
        } catch {
            record(.analysisFailed(error.localizedDescription))
        }
    }

    /// Clears the stored insight and regenerates it (after the user edits the migraine).
    public func regenerateInsight(for migraine: Migraine) async {
        guard supportsAppleIntelligence else { return }
        if migraine.insight?.isEmpty == false {
            try? updateMigraine(migraine) { $0.insight = nil }
        }
        await analyzeNewlyLogged(migraine)
    }

    // MARK: - Quick Bit explanations

    /// A cached (or freshly generated) explanation for an insight; nil when unavailable.
    public func explanation(for insight: Insight) async -> QuickBitExplanation? {
        guard supportsAppleIntelligence else { return nil }
        let key = insight.dedupeKey.key
        if let cached = quickBitExplanations[key] { return cached }
        do {
            guard let explanation = try await intelligence.explain(insight: insight, user: try? loadUser()) else { return nil }
            quickBitExplanations[key] = explanation
            return explanation
        } catch {
            record(.analysisFailed(error.localizedDescription))
            return nil
        }
    }

    // MARK: - Analyst chat

    public func startChat() async {
        guard supportsAppleIntelligence else {
            record(.unavailable)
            return
        }
        let migraines = (try? loadMigraines()) ?? []
        await intelligence.startChat(migraines: migraines, user: try? loadUser())
    }

    /// Sends a message and returns the reply (an apologetic placeholder on failure).
    @discardableResult
    public func send(_ text: String) async -> String {
        guard supportsAppleIntelligence else {
            record(.unavailable)
            return String(localized: "This device does not support Apple Intelligence.")
        }
        isSending = true
        defer { isSending = false }
        do {
            return try await intelligence.send(message: text)
        } catch {
            record(.chatFailed(error.localizedDescription))
            return Self.chatFailureReply
        }
    }

    public func resetChat() {
        intelligence.resetChat()
    }

    /// The reply shown when a send fails (views use it to pick an error haptic).
    public static let chatFailureReply = String(localized: "Sorry, I ran into a problem.")

    // MARK: - Errors

    private func record(_ failure: IntelligenceFailure) {
        errors.append(failure)
        Log.intelligence.error("\(failure.errorDescription ?? "Intelligence failure")")
    }

    public func clearErrors() {
        errors.removeAll()
    }
}

/// The user-facing failures of the intelligence surface.
nonisolated public enum IntelligenceFailure: LocalizedError, Equatable, Sendable {
    case unavailable
    case analysisFailed(String)
    case chatFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable: return String(localized: "Apple Intelligence is not available on this device.")
        case .analysisFailed: return String(localized: "Failed to analyze migraine with Intelligence.")
        case .chatFailed: return String(localized: "Failed to send counselor message.")
        }
    }
}
