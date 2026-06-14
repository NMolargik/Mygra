//
//  MigraineEntity.swift
//  Mygra
//
//  An App Intents entity mirroring a logged migraine. Conforms to
//  IndexedEntity so migraines are surfaced in Spotlight semantic search, and
//  backs intents that take a specific migraine as a parameter.
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData

struct MigraineEntity: AppEntity, IndexedEntity {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let painLevel: Int
    let note: String?
    let triggerNames: [String]

    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Migraine")
    }

    static let defaultQuery = MigraineEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        let dateText = startDate.formatted(date: .abbreviated, time: .shortened)
        let subtitle = note?.isEmpty == false
            ? LocalizedStringResource(stringLiteral: note!)
            : "Pain \(painLevel)/10"
        return DisplayRepresentation(
            title: "Migraine — \(dateText)",
            subtitle: subtitle
        )
    }

    /// Spotlight metadata enabling semantic, on-device search.
    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .text)
        set.title = "Migraine on \(startDate.formatted(date: .abbreviated, time: .omitted))"
        var parts: [String] = ["Pain level \(painLevel) out of 10"]
        if let note, !note.isEmpty { parts.append(note) }
        if !triggerNames.isEmpty { parts.append("Triggers: " + triggerNames.joined(separator: ", ")) }
        set.contentDescription = parts.joined(separator: ". ")
        set.keywords = ["migraine", "headache"] + triggerNames
        set.startDate = startDate
        set.endDate = endDate
        return set
    }
}

extension MigraineEntity {
    @MainActor
    init(_ migraine: Migraine) {
        self.id = migraine.id
        self.startDate = migraine.startDate
        self.endDate = migraine.endDate
        self.painLevel = migraine.painLevel
        self.note = migraine.note
        self.triggerNames = migraine.triggers.map(\.displayName)
            + migraine.customTriggers
    }
}

// MARK: - Query

struct MigraineEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [MigraineEntity] {
        try await fetch { migraines in
            migraines.filter { identifiers.contains($0.id) }
        }
    }

    func suggestedEntities() async throws -> [MigraineEntity] {
        try await fetch { Array($0.prefix(10)) }
    }

    @MainActor
    private func fetch(_ transform: ([Migraine]) -> [Migraine]) throws -> [MigraineEntity] {
        let context = MygraModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<Migraine>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let all = try context.fetch(descriptor)
        return transform(all).map(MigraineEntity.init)
    }
}

// MARK: - View a specific migraine

struct ViewMigraineIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a Migraine"
    static let description = IntentDescription("Opens a specific migraine's details in Mygra.")
    static let openAppWhenRun = true

    @Parameter(title: "Migraine")
    var migraine: MigraineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$migraine)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLink.migraine(migraine.id).storePending(in: UserDefaults(suiteName: AppGroup.id))
        return .result()
    }
}
