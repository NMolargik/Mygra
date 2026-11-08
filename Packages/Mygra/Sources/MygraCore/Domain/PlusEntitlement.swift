//
//  PlusEntitlement.swift
//  MygraCore
//
//  The pure rules behind Mygra Plus: which features it unlocks, who is grandfathered in
//  from the paid-up-front era, and the cached entitlement bookkeeping over a key-value
//  store. StoreKit lives in MygraServices; everything here is host-tested.
//

import Foundation

// MARK: - Features

/// The features Plus unlocks. Everything else in Mygra is free forever, and stored
/// data (including insights generated earlier) is never locked away.
nonisolated public enum PlusFeature: String, CaseIterable, Identifiable, Sendable {
    case assistant
    case quickBits
    case weatherRisk
    case cycleInsights
    case pdfReport
    case csvExport

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .assistant: "sparkles"
        case .quickBits: "lightbulb.max.fill"
        case .weatherRisk: "cloud.bolt.rain.fill"
        case .cycleInsights: "calendar.badge.clock"
        case .pdfReport: "doc.richtext.fill"
        case .csvExport: "tablecells.fill"
        }
    }

    public var title: String {
        switch self {
        case .assistant: String(localized: "Migraine Assistant")
        case .quickBits: String(localized: "Quick Bits & trigger analysis")
        case .weatherRisk: String(localized: "Weather-risk forecasts")
        case .cycleInsights: String(localized: "Cycle insights")
        case .pdfReport: String(localized: "Doctor-ready PDF reports")
        case .csvExport: String(localized: "CSV export")
        }
    }

    public var detail: String {
        switch self {
        case .assistant: String(localized: "Chat with on-device Apple Intelligence about your history.")
        case .quickBits: String(localized: "Spot patterns across triggers, sleep, hydration, and weather.")
        case .weatherRisk: String(localized: "Get notified when conditions turn migraine-prone.")
        case .cycleInsights: String(localized: "See how your attacks line up with your menstrual cycle.")
        case .pdfReport: String(localized: "Share a clean summary with your care team.")
        case .csvExport: String(localized: "Take your raw data anywhere.")
        }
    }

    /// The one-line reason the paywall shows when opened from this feature.
    public var paywallReason: String {
        switch self {
        case .assistant: String(localized: "The Migraine Assistant is part of Mygra Plus.")
        case .quickBits: String(localized: "Quick Bits and trigger analysis are part of Mygra Plus.")
        case .weatherRisk: String(localized: "Weather-risk alerts are part of Mygra Plus.")
        case .cycleInsights: String(localized: "Cycle insights are part of Mygra Plus.")
        case .pdfReport: String(localized: "PDF reports are part of Mygra Plus.")
        case .csvExport: String(localized: "CSV export is part of Mygra Plus.")
        }
    }
}

/// The gate every Plus check goes through. Pure, so the free/Plus split is tested.
nonisolated public struct PlusGate: Sendable, Equatable {
    public let hasPlus: Bool

    public init(hasPlus: Bool) { self.hasPlus = hasPlus }

    /// Whether the feature is usable right now.
    public func unlocks(_ feature: PlusFeature) -> Bool { hasPlus }

    /// Features the user cannot use yet (empty for Plus members).
    public var lockedFeatures: [PlusFeature] { hasPlus ? [] : PlusFeature.allCases }
}

// MARK: - Grandfathering

/// Anyone who bought Mygra while it was paid up front keeps Plus for life.
///
/// `AppTransaction.originalAppVersion` is the **build number** (`CFBundleVersion`) on
/// iOS, not the marketing version. Every paid-era build shipped with a build number
/// below `firstFreeBuild`, so "original build < 200" identifies early supporters.
/// Outside production (Xcode, sandbox, TestFlight) StoreKit reports a placeholder like
/// "1.0", which would grandfather every tester, so only production transactions qualify.
nonisolated public enum GrandfatherRule {
    /// The first build released as free-with-Plus (2.0.0).
    public static let firstFreeBuild = "200"
    /// The marketing version that went free; used when StoreKit hands back a dotted version.
    public static let firstFreeMarketingVersion = "2.0.0"

    public static func qualifies(originalAppVersion: String, isProduction: Bool) -> Bool {
        guard isProduction else { return false }
        return predatesFreeRelease(originalAppVersion)
    }

    /// Whether the version string belongs to the paid-up-front era. Bare integers are
    /// build numbers and compare against `firstFreeBuild`; dotted strings compare against
    /// `firstFreeMarketingVersion`.
    public static func predatesFreeRelease(_ version: String) -> Bool {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = VersionNumber(trimmed) else { return false }
        let threshold = trimmed.contains(".") ? firstFreeMarketingVersion : firstFreeBuild
        guard let cutoff = VersionNumber(threshold) else { return false }
        return components < cutoff
    }
}

/// Dotted numeric version comparison ("1.7.0" < "2.0.0", "48" < "200"). Trailing zeros
/// are insignificant, so "1.7" and "1.7.0" are equal.
nonisolated public struct VersionNumber: Comparable, Sendable {
    public let components: [Int]

    public init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }
        var components: [Int] = []
        for part in parts {
            guard let value = Int(part), value >= 0 else { return nil }
            components.append(value)
        }
        self.components = components
    }

    public static func < (lhs: VersionNumber, rhs: VersionNumber) -> Bool {
        compare(lhs, rhs) == .orderedAscending
    }

    public static func == (lhs: VersionNumber, rhs: VersionNumber) -> Bool {
        compare(lhs, rhs) == .orderedSame
    }

    private static func compare(_ lhs: VersionNumber, _ rhs: VersionNumber) -> ComparisonResult {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}

// MARK: - Cached state

/// The persisted Plus bookkeeping: the grandfather verdict (checked once, cached for
/// good) and whether the early-supporter thank-you has been shown.
nonisolated public struct PlusEntitlementCache {
    private let defaults: any KeyValueStoring

    public init(defaults: any KeyValueStoring) {
        self.defaults = defaults
    }

    /// The cached grandfather verdict, or nil when it has never been checked.
    public var grandfathered: Bool? {
        guard defaults.object(forKey: AppStorageKeys.plusGrandfathered) != nil else { return nil }
        return defaults.bool(forKey: AppStorageKeys.plusGrandfathered)
    }

    public func storeGrandfathered(_ value: Bool) {
        defaults.set(value, forKey: AppStorageKeys.plusGrandfathered)
    }

    /// Clears the verdict so the next launch re-checks (a failed lookup must not stick).
    public func clearGrandfathered() {
        defaults.removeObject(forKey: AppStorageKeys.plusGrandfathered)
    }

    public var hasShownEarlySupporterThanks: Bool {
        defaults.bool(forKey: AppStorageKeys.plusEarlySupporterThanksShown)
    }

    public func markEarlySupporterThanksShown() {
        defaults.set(true, forKey: AppStorageKeys.plusEarlySupporterThanksShown)
    }

    /// Whether to show the one-time "Plus is yours for life" thank-you right now.
    public var shouldShowEarlySupporterThanks: Bool {
        grandfathered == true && !hasShownEarlySupporterThanks
    }
}
