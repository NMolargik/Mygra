//
//  MigraineEntity.swift
//  Mygra
//
//  An App Intents entity mirroring a logged migraine. Conforms to IndexedEntity so
//  migraines are surfaced in Spotlight semantic search, and backs intents that take a
//  specific migraine as a parameter.
//

import AppIntents
import CoreSpotlight
import Foundation
import MygraComposition
import MygraCore

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
        let subtitle: LocalizedStringResource = (note?.isEmpty == false)
            ? LocalizedStringResource(stringLiteral: note!)
            : "Pain \(painLevel)/10"
        return DisplayRepresentation(title: "Migraine — \(dateText)", subtitle: subtitle)
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
        id = migraine.id
        startDate = migraine.startDate
        endDate = migraine.endDate
        painLevel = migraine.painLevel
        note = migraine.note
        triggerNames = migraine.allTriggerNames
    }
}

// MARK: - Query

struct MigraineEntityQuery: EntityQuery {
    @Dependency private var session: SessionController

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [MigraineEntity] {
        try session.loadMigraines()
            .filter { identifiers.contains($0.id) }
            .map(MigraineEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [MigraineEntity] {
        try session.loadMigraines()
            .prefix(10)
            .map(MigraineEntity.init)
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
        DeepLink.migraine(migraine.id).storePending(in: AppGroup.defaults)
        return .result()
    }
}
