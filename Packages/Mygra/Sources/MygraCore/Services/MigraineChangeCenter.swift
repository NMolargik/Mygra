//
//  MigraineChangeCenter.swift
//  MygraCore
//
//  One multicast change stream for the migraine store. Repositories notify after every
//  successful write and CloudSyncManager notifies on CloudKit imports, so screens,
//  insights, status sync, and Spotlight observe a single stream instead of per-screen
//  callbacks (replaces the old refresh()/NotificationCenter pair on MigraineManager).
//

import Foundation

/// What changed. Payloads let observers react to specific events (e.g. analyze a newly
/// logged migraine) without polling.
nonisolated public enum MigraineChange: Equatable, Sendable {
    /// A migraine was inserted.
    case migraineLogged(UUID)
    /// A migraine's fields (including its end date) changed.
    case migraineUpdated(UUID)
    /// A migraine was deleted.
    case migraineDeleted(UUID)
    /// Tags changed (create/update/delete/reorder/assignment).
    case tagsChanged
    /// The user profile changed.
    case userChanged
    /// Many records changed at once (delete-all, sample data, CloudKit import).
    case bulk
}

@MainActor
public final class MigraineChangeCenter {

    private var continuations: [UUID: AsyncStream<MigraineChange>.Continuation] = [:]

    public init() {}

    /// A stream that yields after every successful mutation of migraine data.
    public func changes() -> AsyncStream<MigraineChange> {
        let (stream, continuation) = AsyncStream<MigraineChange>.makeStream()
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.continuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    /// Broadcasts a change to every subscriber.
    public func notify(_ change: MigraineChange) {
        for continuation in continuations.values {
            continuation.yield(change)
        }
    }
}

// MARK: - Use case

@MainActor
public protocol ObserveMigraineChanges {
    func callAsFunction() -> AsyncStream<MigraineChange>
}

public struct ObserveMigraineChangesUseCase: ObserveMigraineChanges {
    private let center: MigraineChangeCenter
    public init(center: MigraineChangeCenter) { self.center = center }
    public func callAsFunction() -> AsyncStream<MigraineChange> {
        center.changes()
    }
}
