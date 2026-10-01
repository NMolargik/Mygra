//
//  DefaultTagRepository.swift
//  MygraData
//
//  The SwiftData-backed `TagRepository`. Keeps `sortIndex` contiguous, detaches tags
//  from migraines before deleting, and notifies the change stream after every write.
//

import Foundation
import SwiftData
import MygraCore
import os

@MainActor
public final class DefaultTagRepository: TagRepository {

    private let container: ModelContainer
    private let changeCenter: MigraineChangeCenter?

    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer, changeCenter: MigraineChangeCenter? = nil) {
        self.container = container
        self.changeCenter = changeCenter
    }

    public func tags() throws(PersistenceError) -> [MigraineTag] {
        let descriptor = FetchDescriptor<MigraineTag>(
            sortBy: [
                SortDescriptor(\.sortIndex, order: .forward),
                SortDescriptor(\.name, order: .forward),
            ]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            Log.migraine.error("Tag fetch failed: \(error.localizedDescription)")
            throw .fetchFailed(error.localizedDescription)
        }
    }

    @discardableResult
    public func create(name: String, colorHex: String) throws(PersistenceError) -> MigraineTag {
        // Read the committed store so back-to-back creates never reuse an index.
        let nextIndex = (try tags().map(\.sortIndex).max() ?? -1) + 1
        let tag = MigraineTag(name: name, colorHex: colorHex, sortIndex: nextIndex)
        context.insert(tag)
        try save(operation: "create tag")
        return tag
    }

    public func update(_ tag: MigraineTag, name: String?, colorHex: String?) throws(PersistenceError) {
        if let name { tag.name = name }
        if let colorHex { tag.colorHex = colorHex }
        try save(operation: "update tag")
    }

    public func delete(_ tag: MigraineTag) throws(PersistenceError) {
        for migraine in tag.migraines ?? [] {
            migraine.tags?.removeAll { $0.id == tag.id }
        }
        context.delete(tag)
        try save(operation: "delete tag")
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) throws(PersistenceError) {
        let reordered = try tags().moving(fromOffsets: source, toOffset: destination)
        for (index, tag) in reordered.enumerated() {
            tag.sortIndex = index
        }
        try save(operation: "reorder tags")
    }

    public func setTags(_ tags: [MigraineTag], for migraine: Migraine) throws(PersistenceError) {
        migraine.tags = tags
        try save(operation: "assign tags")
    }

    // MARK: - Saving

    private func save(operation: String) throws(PersistenceError) {
        do {
            try context.save()
        } catch {
            Log.migraine.error("Failed to \(operation): \(error.localizedDescription)")
            throw .saveFailed(error.localizedDescription)
        }
        changeCenter?.notify(.tagsChanged)
    }
}
