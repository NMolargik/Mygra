//
//  CycleDataModel.swift
//  MygraFeatureShared
//
//  The opt-in menstrual-cycle surface: whether the user turned Cycle Insights on, the
//  period days read from Health (read only), and the perimenstrual statistic. Nothing
//  is requested or read until the user turns it on, and nothing is shown without Plus.
//

import Foundation
import Observation
import MygraCore
import os

@MainActor
@Observable
public final class CycleDataModel {

    @ObservationIgnored private let flow: (any MenstrualFlowProviding)?
    @ObservationIgnored private let defaults: any KeyValueStoring
    @ObservationIgnored private let entitlement: any EntitlementProviding
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date

    /// The user's choice (persisted). Independent of Plus; see `isActive`.
    public private(set) var isEnabled: Bool
    public private(set) var isLoading = false
    /// Start-of-day dates with recorded flow.
    public private(set) var flowDays: Set<Date> = []
    public private(set) var periodStarts: [Date] = []
    /// Whether a Health read has completed since the feature was turned on.
    public private(set) var hasLoaded = false
    #if DEBUG
    /// DEBUG: canned days installed; a real (empty) Health read must not wipe them.
    private var isDebugPinned = false
    #endif

    /// How far back flow is read.
    public static let lookBackYears = 2

    public init(
        flow: (any MenstrualFlowProviding)?,
        entitlement: any EntitlementProviding,
        defaults: any KeyValueStoring = UserDefaults.standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.flow = flow
        self.entitlement = entitlement
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        isEnabled = defaults.bool(forKey: AppStorageKeys.cycleInsightsEnabled)
    }

    /// Whether to show anything: opted in, Plus, and Health available.
    public var isActive: Bool {
        isEnabled && flow != nil && entitlement.gate.unlocks(.cycleInsights)
    }

    /// Turns the feature on (asking Health for read access first) or off (forgetting the data).
    public func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled else { return }
        if enabled {
            guard let flow, entitlement.gate.unlocks(.cycleInsights) else { return }
            _ = await flow.requestMenstrualFlowAccess()
            isEnabled = true
            defaults.set(true, forKey: AppStorageKeys.cycleInsightsEnabled)
            await refresh()
        } else {
            isEnabled = false
            defaults.set(false, forKey: AppStorageKeys.cycleInsightsEnabled)
            flowDays = []
            periodStarts = []
            hasLoaded = false
        }
    }

    /// Re-reads flow from Health. A no-op unless the feature is active.
    public func refresh() async {
        #if DEBUG
        if isDebugPinned { return }
        #endif
        guard isActive, let flow, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let current = now()
        let start = calendar.date(byAdding: .year, value: -Self.lookBackYears, to: current) ?? current
        let days = await flow.fetchMenstrualFlowDays(since: start, calendar: calendar)
        let normalized = Set(days.map { calendar.startOfDay(for: $0) })
        flowDays = normalized
        periodStarts = MenstrualCycles.periodStarts(fromFlowDays: normalized, calendar: calendar)
        hasLoaded = true
    }

    /// Whether the calendar should mark this day as a period day.
    public func isPeriodDay(_ date: Date) -> Bool {
        isActive && flowDays.contains(calendar.startOfDay(for: date))
    }

    /// The statistic for the given attacks; nil when the feature is not active.
    public func result(for migraines: [Migraine]) -> PerimenstrualResult? {
        guard isActive else { return nil }
        return MenstrualCycles.analyze(attackStarts: migraines.map(\.startDate), periodStarts: periodStarts, calendar: calendar)
    }

    #if DEBUG
    /// DEBUG: installs canned flow days and turns the feature on (screenshots, previews).
    public func installDebugFlowDays(_ days: [Date]) {
        isEnabled = true
        isDebugPinned = true
        let normalized = Set(days.map { calendar.startOfDay(for: $0) })
        flowDays = normalized
        periodStarts = MenstrualCycles.periodStarts(fromFlowDays: normalized, calendar: calendar)
        hasLoaded = true
    }
    #endif
}
