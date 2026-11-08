//
//  PlusEntitlementTests.swift
//  MygraCoreTests
//
//  The Mygra Plus rules: free vs Plus gating, the early-supporter grandfather rule, and
//  the cached entitlement bookkeeping.
//

import Foundation
import Testing
@testable import MygraCore

@Suite("Plus products")
struct PlusProductTests {
    @Test func productIDsMatchAppStoreConnect() {
        #expect(PlusProduct.monthly.rawValue == "com.molargiksoftware.Mygra.plus.monthly")
        #expect(PlusProduct.yearly.rawValue == "com.molargiksoftware.Mygra.plus.yearly")
        #expect(PlusProduct.lifetime.rawValue == "com.molargiksoftware.Mygra.plus.lifetime")
        #expect(PlusProduct.productIDs.count == 3)
        #expect(PlusProduct.subscriptionProductIDs == [PlusProduct.monthly.rawValue, PlusProduct.yearly.rawValue])
        #expect(PlusProduct.lifetime.isSubscription == false)
        #expect(PlusProduct.yearly.isSubscription)
        #expect(PlusProduct.subscriptionGroupName == "Mygra Plus")
    }
}

@Suite("PlusGate")
struct PlusGateTests {
    @Test("the free tier locks every Plus feature and nothing else")
    func freeTier() {
        let gate = PlusGate(hasPlus: false)
        for feature in PlusFeature.allCases {
            #expect(gate.unlocks(feature) == false)
        }
        #expect(gate.lockedFeatures == PlusFeature.allCases)
    }

    @Test("Plus unlocks every gated feature")
    func plusTier() {
        let gate = PlusGate(hasPlus: true)
        for feature in PlusFeature.allCases {
            #expect(gate.unlocks(feature))
        }
        #expect(gate.lockedFeatures.isEmpty)
    }

    @Test("the gated set is exactly the six Plus features")
    func gatedFeatures() {
        #expect(Set(PlusFeature.allCases) == [.assistant, .quickBits, .weatherRisk, .cycleInsights, .pdfReport, .csvExport])
        for feature in PlusFeature.allCases {
            #expect(!feature.title.isEmpty)
            #expect(!feature.paywallReason.isEmpty)
            #expect(!feature.systemImage.isEmpty)
        }
    }

    @Test("a fixed entitlement exposes a matching gate")
    @MainActor
    func entitlementGate() {
        let entitlement = FixedEntitlement(hasPlus: false)
        #expect(entitlement.gate == PlusGate(hasPlus: false))
        entitlement.hasPlus = true
        #expect(entitlement.gate.unlocks(.pdfReport))
    }
}

@Suite("GrandfatherRule")
struct GrandfatherRuleTests {
    @Test("paid-era production builds qualify", arguments: ["1", "42", "45", "47", "48", "199"])
    func paidEraBuilds(build: String) {
        #expect(GrandfatherRule.qualifies(originalAppVersion: build, isProduction: true))
    }

    @Test("the free release and anything later do not", arguments: ["200", "201", "250", "1000"])
    func freeEraBuilds(build: String) {
        #expect(GrandfatherRule.qualifies(originalAppVersion: build, isProduction: true) == false)
    }

    @Test("dotted marketing versions compare against 2.0.0")
    func marketingVersions() {
        #expect(GrandfatherRule.predatesFreeRelease("1.7.0"))
        #expect(GrandfatherRule.predatesFreeRelease("1.4.1"))
        #expect(GrandfatherRule.predatesFreeRelease("1.99.9"))
        #expect(GrandfatherRule.predatesFreeRelease("2.0.0") == false)
        #expect(GrandfatherRule.predatesFreeRelease("2.0") == false)
        #expect(GrandfatherRule.predatesFreeRelease("2.1.0") == false)
        #expect(GrandfatherRule.predatesFreeRelease("10.0") == false)
    }

    @Test("sandbox, TestFlight, and Xcode never grandfather (StoreKit reports a placeholder)")
    func nonProductionIsNeverGrandfathered() {
        #expect(GrandfatherRule.qualifies(originalAppVersion: "1.0", isProduction: false) == false)
        #expect(GrandfatherRule.qualifies(originalAppVersion: "1", isProduction: false) == false)
        #expect(GrandfatherRule.qualifies(originalAppVersion: "48", isProduction: false) == false)
    }

    @Test("unparseable versions fail closed")
    func garbage() {
        #expect(GrandfatherRule.qualifies(originalAppVersion: "", isProduction: true) == false)
        #expect(GrandfatherRule.qualifies(originalAppVersion: "beta", isProduction: true) == false)
        #expect(GrandfatherRule.qualifies(originalAppVersion: "1.a", isProduction: true) == false)
        #expect(GrandfatherRule.qualifies(originalAppVersion: "-1", isProduction: true) == false)
    }

    @Test func versionNumberOrdering() {
        #expect(VersionNumber("1.7.0")! < VersionNumber("2.0.0")!)
        #expect(VersionNumber("1.7")! < VersionNumber("1.7.1")!)
        #expect(VersionNumber("1.7.0")! == VersionNumber("1.7")!)
        #expect(VersionNumber("48")! < VersionNumber("200")!)
        #expect((VersionNumber("200")! < VersionNumber("200")!) == false)
        #expect(VersionNumber("") == nil)
        #expect(VersionNumber("1..2") == nil)
    }
}

@Suite("PlusEntitlementCache")
struct PlusEntitlementCacheTests {
    @Test("the verdict is unknown until stored, then sticks either way")
    func cachedVerdict() {
        let defaults = FakeKeyValueStore()
        let cache = PlusEntitlementCache(defaults: defaults)
        #expect(cache.grandfathered == nil)

        cache.storeGrandfathered(false)
        #expect(cache.grandfathered == false)

        cache.storeGrandfathered(true)
        #expect(cache.grandfathered == true)
        #expect(PlusEntitlementCache(defaults: defaults).grandfathered == true)

        cache.clearGrandfathered()
        #expect(cache.grandfathered == nil)
    }

    @Test("the early-supporter thank-you shows once, and only for grandfathered users")
    func earlySupporterThanks() {
        let defaults = FakeKeyValueStore()
        let cache = PlusEntitlementCache(defaults: defaults)
        #expect(cache.shouldShowEarlySupporterThanks == false)

        cache.storeGrandfathered(false)
        #expect(cache.shouldShowEarlySupporterThanks == false)

        cache.storeGrandfathered(true)
        #expect(cache.shouldShowEarlySupporterThanks)

        cache.markEarlySupporterThanksShown()
        #expect(cache.shouldShowEarlySupporterThanks == false)
        #expect(cache.hasShownEarlySupporterThanks)
    }
}

@Suite("ReviewMilestone export")
struct ReviewMilestoneExportTests {
    @Test func promptsOnlyOnFirstExport() {
        #expect(ReviewMilestone.shouldPromptAfterExport(hasPrompted: false))
        #expect(ReviewMilestone.shouldPromptAfterExport(hasPrompted: true) == false)
    }
}
