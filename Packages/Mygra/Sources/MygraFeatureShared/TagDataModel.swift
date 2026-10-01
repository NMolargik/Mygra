//
//  TagDataModel.swift
//  MygraFeatureShared
//
//  The environment-injected tag surface (successor to TagManager) over use-cases, with
//  toasted failures and change-stream refreshes.
//

import Foundation
import Observation
import MygraCore
import MygraDesignSystem
import os

@MainActor
@Observable
public final class TagDataModel {

    @ObservationIgnored private let loadTags: any LoadTags
    @ObservationIgnored private let createTagUseCase: any CreateTag
    @ObservationIgnored private let updateTagUseCase: any UpdateTag
    @ObservationIgnored private let deleteTagUseCase: any DeleteTag
    @ObservationIgnored private let reorderTagsUseCase: any ReorderTags
    @ObservationIgnored private let assignTagsUseCase: any AssignTags
    @ObservationIgnored private let observeChanges: any ObserveMigraineChanges
    @ObservationIgnored private let toastManager: ToastManager

    /// Every tag in user order.
    public private(set) var tags: [MigraineTag] = []

    @ObservationIgnored private var observationTask: Task<Void, Never>?

    public init(
        loadTags: any LoadTags,
        createTag: any CreateTag,
        updateTag: any UpdateTag,
        deleteTag: any DeleteTag,
        reorderTags: any ReorderTags,
        assignTags: any AssignTags,
        observeChanges: any ObserveMigraineChanges,
        toastManager: ToastManager
    ) {
        self.loadTags = loadTags
        self.createTagUseCase = createTag
        self.updateTagUseCase = updateTag
        self.deleteTagUseCase = deleteTag
        self.reorderTagsUseCase = reorderTags
        self.assignTagsUseCase = assignTags
        self.observeChanges = observeChanges
        self.toastManager = toastManager
        refresh()
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
                switch change {
                case .tagsChanged, .bulk: self.refresh()
                default: break
                }
            }
        }
    }

    public func refresh() {
        do {
            tags = try loadTags()
        } catch {
            Log.migraine.error("Tag refresh failed: \(error.localizedDescription)")
            toastManager.show(error: error)
        }
    }

    @discardableResult
    public func create(name: String, colorHex: String = MigraineTag.defaultColorHex) -> MigraineTag? {
        surfacing(fallback: nil) { try createTagUseCase(name: name, colorHex: colorHex) }
    }

    public func update(_ tag: MigraineTag, name: String? = nil, colorHex: String? = nil) {
        surfacing(fallback: ()) { try updateTagUseCase(tag, name: name, colorHex: colorHex) }
    }

    public func delete(_ tag: MigraineTag) {
        surfacing(fallback: ()) { try deleteTagUseCase(tag) }
    }

    /// Drag-to-reorder from a SwiftUI `onMove`.
    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        surfacing(fallback: ()) { try reorderTagsUseCase(fromOffsets: source, toOffset: destination) }
    }

    public func setTags(_ tags: [MigraineTag], for migraine: Migraine) {
        surfacing(fallback: ()) { try assignTagsUseCase(tags, to: migraine) }
    }

    /// Runs a store operation, refreshing the cache on success and toasting on failure.
    private func surfacing<T>(fallback: T, _ operation: () throws -> T) -> T {
        do {
            let result = try operation()
            refresh()
            return result
        } catch {
            Log.migraine.error("\(error.localizedDescription)")
            toastManager.show(error: error)
            return fallback
        }
    }
}
