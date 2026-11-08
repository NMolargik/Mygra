//
//  CycleDataModelTests.swift
//  MygraFeatureSharedTests
//
//  The Cycle Insights opt-in: nothing is requested or read until it is turned on, and
//  nothing is active without Plus.
//

import Foundation
import Testing
import MygraCore
@testable import MygraFeatureShared

@MainActor
private final class FakeFlow: MenstrualFlowProviding {
    var days: [Date] = []
    private(set) var accessRequests = 0
    private(set) var fetches = 0
    func requestMenstrualFlowAccess() async -> Bool { accessRequests += 1; return true }
    func fetchMenstrualFlowDays(since start: Date, calendar: Calendar) async -> [Date] { fetches += 1; return days }
}

private final class MemoryDefaults: KeyValueStoring, @unchecked Sendable {
    private var storage: [String: Any] = [:]
    func bool(forKey defaultName: String) -> Bool { storage[defaultName] as? Bool ?? false }
    func double(forKey defaultName: String) -> Double { storage[defaultName] as? Double ?? 0 }
    func integer(forKey defaultName: String) -> Int { storage[defaultName] as? Int ?? 0 }
    func string(forKey defaultName: String) -> String? { storage[defaultName] as? String }
    func data(forKey defaultName: String) -> Data? { storage[defaultName] as? Data }
    func object(forKey defaultName: String) -> Any? { storage[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) { storage[defaultName] = value }
    func removeObject(forKey defaultName: String) { storage.removeValue(forKey: defaultName) }
}

@Suite("CycleDataModel")
@MainActor
struct CycleDataModelTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ n: Int) -> Date {
        utc.date(byAdding: .day, value: n, to: utc.date(from: DateComponents(year: 2026, month: 1, day: 1))!)!
    }

    @Test("off by default: nothing is requested or read")
    func offByDefault() async {
        let flow = FakeFlow()
        let model = CycleDataModel(flow: flow, entitlement: FixedEntitlement(hasPlus: true), defaults: MemoryDefaults(), calendar: utc)
        await model.refresh()
        #expect(!model.isEnabled && !model.isActive)
        #expect(flow.accessRequests == 0 && flow.fetches == 0)
        #expect(model.result(for: []) == nil)
        #expect(!model.isPeriodDay(day(0)))
    }

    @Test("turning it on asks for access once, then reads and exposes period days")
    func turnOn() async {
        let flow = FakeFlow()
        flow.days = [0, 1, 2, 28, 29].map(day)
        let defaults = MemoryDefaults()
        let model = CycleDataModel(flow: flow, entitlement: FixedEntitlement(hasPlus: true), defaults: defaults, calendar: utc)
        await model.setEnabled(true)
        #expect(flow.accessRequests == 1)
        #expect(model.isActive && model.hasLoaded)
        #expect(model.isPeriodDay(day(1)) && !model.isPeriodDay(day(10)))
        #expect(model.periodStarts == [day(0), day(28)])
        #expect(defaults.bool(forKey: AppStorageKeys.cycleInsightsEnabled))
    }

    @Test("without Plus it cannot be turned on and requests nothing")
    func needsPlus() async {
        let flow = FakeFlow()
        let model = CycleDataModel(flow: flow, entitlement: FixedEntitlement(hasPlus: false), defaults: MemoryDefaults(), calendar: utc)
        await model.setEnabled(true)
        #expect(!model.isEnabled)
        #expect(flow.accessRequests == 0)
    }

    @Test("turning it off forgets the days")
    func turnOff() async {
        let flow = FakeFlow()
        flow.days = [0, 28].map(day)
        let model = CycleDataModel(flow: flow, entitlement: FixedEntitlement(hasPlus: true), defaults: MemoryDefaults(), calendar: utc)
        await model.setEnabled(true)
        await model.setEnabled(false)
        #expect(model.flowDays.isEmpty && model.periodStarts.isEmpty && !model.isActive)
    }

    @Test("the choice persists but lapses with Plus")
    func persistsAndLapses() async {
        let defaults = MemoryDefaults()
        defaults.set(true, forKey: AppStorageKeys.cycleInsightsEnabled)
        let lapsed = CycleDataModel(flow: FakeFlow(), entitlement: FixedEntitlement(hasPlus: false), defaults: defaults, calendar: utc)
        #expect(lapsed.isEnabled && !lapsed.isActive)
        let active = CycleDataModel(flow: FakeFlow(), entitlement: FixedEntitlement(hasPlus: true), defaults: defaults, calendar: utc)
        #expect(active.isActive)
    }
}
