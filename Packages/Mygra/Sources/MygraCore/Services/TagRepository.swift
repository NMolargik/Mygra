//
//  TagRepository.swift
//  MygraCore
//
//  The user-defined tag boundary: CRUD, drag-to-reorder (contiguous `sortIndex`), and
//  assignment to migraines.
//

import Foundation

@MainActor
public protocol TagRepository: AnyObject {
    /// All tags in user order (then by name).
    func tags() throws(PersistenceError) -> [MigraineTag]

    /// Creates a tag at the end of the list.
    @discardableResult
    func create(name: String, colorHex: String) throws(PersistenceError) -> MigraineTag

    /// Renames and/or recolors a tag.
    func update(_ tag: MigraineTag, name: String?, colorHex: String?) throws(PersistenceError)

    /// Deletes a tag, detaching it from every migraine first.
    func delete(_ tag: MigraineTag) throws(PersistenceError)

    /// Applies a drag-to-reorder move and renumbers `sortIndex` to match.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) throws(PersistenceError)

    /// Replaces a migraine's tags.
    func setTags(_ tags: [MigraineTag], for migraine: Migraine) throws(PersistenceError)
}

// MARK: - Use cases

@MainActor
public protocol LoadTags {
    func callAsFunction() throws(PersistenceError) -> [MigraineTag]
}

public struct LoadTagsUseCase: LoadTags {
    private let repository: any TagRepository
    public init(repository: any TagRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) -> [MigraineTag] {
        try repository.tags()
    }
}

@MainActor
public protocol CreateTag {
    @discardableResult
    func callAsFunction(name: String, colorHex: String) throws(PersistenceError) -> MigraineTag
}

public struct CreateTagUseCase: CreateTag {
    private let repository: any TagRepository
    public init(repository: any TagRepository) { self.repository = repository }
    @discardableResult
    public func callAsFunction(name: String, colorHex: String) throws(PersistenceError) -> MigraineTag {
        try repository.create(name: name, colorHex: colorHex)
    }
}

@MainActor
public protocol UpdateTag {
    func callAsFunction(_ tag: MigraineTag, name: String?, colorHex: String?) throws(PersistenceError)
}

public struct UpdateTagUseCase: UpdateTag {
    private let repository: any TagRepository
    public init(repository: any TagRepository) { self.repository = repository }
    public func callAsFunction(_ tag: MigraineTag, name: String?, colorHex: String?) throws(PersistenceError) {
        try repository.update(tag, name: name, colorHex: colorHex)
    }
}

@MainActor
public protocol DeleteTag {
    func callAsFunction(_ tag: MigraineTag) throws(PersistenceError)
}

public struct DeleteTagUseCase: DeleteTag {
    private let repository: any TagRepository
    public init(repository: any TagRepository) { self.repository = repository }
    public func callAsFunction(_ tag: MigraineTag) throws(PersistenceError) {
        try repository.delete(tag)
    }
}

@MainActor
public protocol ReorderTags {
    func callAsFunction(fromOffsets source: IndexSet, toOffset destination: Int) throws(PersistenceError)
}

public struct ReorderTagsUseCase: ReorderTags {
    private let repository: any TagRepository
    public init(repository: any TagRepository) { self.repository = repository }
    public func callAsFunction(fromOffsets source: IndexSet, toOffset destination: Int) throws(PersistenceError) {
        try repository.move(fromOffsets: source, toOffset: destination)
    }
}

@MainActor
public protocol AssignTags {
    func callAsFunction(_ tags: [MigraineTag], to migraine: Migraine) throws(PersistenceError)
}

public struct AssignTagsUseCase: AssignTags {
    private let repository: any TagRepository
    public init(repository: any TagRepository) { self.repository = repository }
    public func callAsFunction(_ tags: [MigraineTag], to migraine: Migraine) throws(PersistenceError) {
        try repository.setTags(tags, for: migraine)
    }
}

// MARK: - Pure reorder helper

nonisolated extension Array {
    /// Foundation-only `move(fromOffsets:toOffset:)` (the SwiftUI one isn't visible to
    /// SwiftUI-free modules under MemberImportVisibility).
    public func moving(fromOffsets source: IndexSet, toOffset destination: Int) -> [Element] {
        var reordered = self
        let moving = source.sorted().map { reordered[$0] }
        for index in source.sorted(by: >) {
            reordered.remove(at: index)
        }
        let insertionPoint = destination - source.filter { $0 < destination }.count
        reordered.insert(contentsOf: moving, at: insertionPoint)
        return reordered
    }
}
