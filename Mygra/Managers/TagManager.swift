//
//  TagManager.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import Foundation
import SwiftData
import Observation
import os

/// Manages user-defined migraine tags.
@MainActor
@Observable
final class TagManager {
    // MARK: - Dependencies
    // Retain the container: a ModelContext does not retain it.
    @ObservationIgnored
    private let container: ModelContainer
    @ObservationIgnored
    private let context: ModelContext

    // MARK: - Source of truth
    private(set) var tags: [MigraineTag] = []

    // MARK: - Init
    init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
        Task { await refresh() }
    }

    // MARK: - Fetch / Refresh

    /// Fetches all tags in user-defined order, falling back to name.
    func refresh() async {
        do {
            let desc = FetchDescriptor<MigraineTag>(
                sortBy: [
                    SortDescriptor(\.sortIndex, order: .forward),
                    SortDescriptor(\.name, order: .forward)
                ]
            )
            tags = try context.fetch(desc)
        } catch {
            Log.migraine.error("TagManager: Failed to fetch tags: \(error)")
            tags = []
        }
    }

    // MARK: - CRUD Operations

    /// Creates a new tag with the given name and color.
    @discardableResult
    func create(name: String, colorHex: String = "#8B5CF6") -> MigraineTag {
        // Read the committed store rather than the cached `tags` array: refresh
        // is async, so back-to-back creates would otherwise reuse sortIndex 0.
        let existing = (try? context.fetch(FetchDescriptor<MigraineTag>())) ?? []
        let nextIndex = (existing.map(\.sortIndex).max() ?? -1) + 1
        let tag = MigraineTag(name: name, colorHex: colorHex, sortIndex: nextIndex)
        context.insert(tag)
        saveAndRefresh()
        return tag
    }

    /// Reorders tags in response to a drag, persisting the new `sortIndex` values.
    /// Uses a Foundation-only move so this manager stays free of SwiftUI.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var reordered = tags
        let moving = source.sorted().map { reordered[$0] }
        for index in source.sorted(by: >) {
            reordered.remove(at: index)
        }
        let insertionPoint = destination - source.filter { $0 < destination }.count
        reordered.insert(contentsOf: moving, at: insertionPoint)
        for (index, tag) in reordered.enumerated() {
            tag.sortIndex = index
        }
        saveAndRefresh()
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
            Log.migraine.error("TagManager: Failed to save context: \(error)")
        }
        Task { await refresh() }
    }
}
