//
//  TagManager.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import Foundation
import SwiftData
import Observation

/// Manages user-defined migraine tags.
@MainActor
@Observable
final class TagManager {
    // MARK: - Dependencies
    @ObservationIgnored
    private let context: ModelContext

    // MARK: - Source of truth
    private(set) var tags: [MigraineTag] = []

    // MARK: - Init
    init(context: ModelContext) {
        self.context = context
        Task { await refresh() }
    }

    // MARK: - Fetch / Refresh

    /// Fetches all tags sorted by name.
    func refresh() async {
        do {
            let desc = FetchDescriptor<MigraineTag>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            tags = try context.fetch(desc)
        } catch {
            print("TagManager: Failed to fetch tags: \(error)")
            tags = []
        }
    }

    // MARK: - CRUD Operations

    /// Creates a new tag with the given name and color.
    @discardableResult
    func create(name: String, colorHex: String = "#8B5CF6") -> MigraineTag {
        let tag = MigraineTag(name: name, colorHex: colorHex)
        context.insert(tag)
        saveAndRefresh()
        return tag
    }

    /// Updates an existing tag.
    func update(_ tag: MigraineTag, name: String? = nil, colorHex: String? = nil) {
        if let name = name {
            tag.name = name
        }
        if let colorHex = colorHex {
            tag.colorHex = colorHex
        }
        saveAndRefresh()
    }

    /// Deletes a tag.
    func delete(_ tag: MigraineTag) {
        // Remove the tag from all associated migraines first
        for migraine in tag.migraines ?? [] {
            migraine.tags?.removeAll { $0.id == tag.id }
        }
        context.delete(tag)
        saveAndRefresh()
    }

    // MARK: - Tag Assignment

    /// Assigns a tag to a migraine.
    func assign(_ tag: MigraineTag, to migraine: Migraine) {
        guard !(migraine.tags ?? []).contains(where: { $0.id == tag.id }) else { return }
        if migraine.tags == nil {
            migraine.tags = []
        }
        migraine.tags?.append(tag)
        saveAndRefresh()
    }

    /// Removes a tag from a migraine.
    func remove(_ tag: MigraineTag, from migraine: Migraine) {
        migraine.tags?.removeAll { $0.id == tag.id }
        saveAndRefresh()
    }

    /// Sets all tags for a migraine, replacing existing tags.
    func setTags(_ tags: [MigraineTag], for migraine: Migraine) {
        migraine.tags = tags
        saveAndRefresh()
    }

    // MARK: - Helpers

    private func saveAndRefresh() {
        do {
            try context.save()
        } catch {
            print("TagManager: Failed to save context: \(error)")
        }
        Task { await refresh() }
    }
}
