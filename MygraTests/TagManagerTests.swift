//
//  TagManagerTests.swift
//  MygraTests
//
//  Behavior tests for tag ordering over an isolated SwiftData container.
//

import Foundation
import SwiftData
import Testing
@testable import Mygra

@Suite("TagManager", .serialized)
@MainActor
struct TagManagerTests {

    private func makeManager() throws -> (TagManager, ModelContainer) {
        let container = try makeTestContainer()
        return (TagManager(container: container), container)
    }

    @Test func createAssignsIncreasingSortIndex() async throws {
        let (manager, _) = try makeManager()
        manager.create(name: "A")
        manager.create(name: "B")
        manager.create(name: "C")
        await manager.refresh()

        #expect(manager.tags.map(\.name) == ["A", "B", "C"])
        #expect(manager.tags.map(\.sortIndex) == [0, 1, 2])
    }

    @Test func moveReordersAndRenumbers() async throws {
        let (manager, _) = try makeManager()
        manager.create(name: "A")
        manager.create(name: "B")
        manager.create(name: "C")
        await manager.refresh()

        // Move the first tag (A) to the end.
        manager.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        await manager.refresh()

        #expect(manager.tags.map(\.name) == ["B", "C", "A"])
        // Sort indices are contiguous from zero after a move.
        #expect(manager.tags.map(\.sortIndex) == [0, 1, 2])
    }

    @Test func moveUpwardPlacesItemBeforeTarget() async throws {
        let (manager, _) = try makeManager()
        manager.create(name: "A")
        manager.create(name: "B")
        manager.create(name: "C")
        await manager.refresh()

        // Move the last tag (C) to the front.
        manager.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        await manager.refresh()

        #expect(manager.tags.map(\.name) == ["C", "A", "B"])
    }
}
