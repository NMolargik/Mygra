//
//  PlusProduct.swift
//  MygraCore
//
//  The Mygra Plus products. Monthly and yearly live in one subscription group; lifetime
//  is a non-consumable. Entitlement checks accept any of them.
//

import Foundation

nonisolated public enum PlusProduct: String, CaseIterable, Identifiable, Sendable {
    case monthly = "com.molargiksoftware.Mygra.plus.monthly"
    case yearly = "com.molargiksoftware.Mygra.plus.yearly"
    case lifetime = "com.molargiksoftware.Mygra.plus.lifetime"

    public var id: String { rawValue }

    /// The App Store Connect subscription group both auto-renewing plans belong to.
    public static let subscriptionGroupName = "Mygra Plus"

    /// Whether this is an auto-renewing subscription (vs the one-time purchase).
    public var isSubscription: Bool { self != .lifetime }

    /// Every product ID that grants Plus.
    public static var productIDs: Set<String> { Set(allCases.map(\.rawValue)) }

    /// The auto-renewing plans, in the order the paywall lists them.
    public static var subscriptions: [PlusProduct] { [.monthly, .yearly] }

    /// The product IDs `SubscriptionStoreView` loads.
    public static var subscriptionProductIDs: [String] { subscriptions.map(\.rawValue) }

    public var displayName: String {
        switch self {
        case .monthly: String(localized: "Monthly")
        case .yearly: String(localized: "Yearly")
        case .lifetime: String(localized: "Lifetime")
        }
    }
}
