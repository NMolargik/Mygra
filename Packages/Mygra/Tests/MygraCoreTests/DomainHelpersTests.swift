//
//  DomainHelpersTests.swift
//  MygraCoreTests
//
//  Small pure helpers: units, intake staging, review milestone, onboarding order,
//  trigger catalog, enums.
//

import Foundation
import Testing
import MygraCore

@Suite("Domain helpers")
struct DomainHelpersTests {
    @Test func snapRoundsAndClamps() {
        #expect(abs(UnitConversion.snap(0.26, toStep: 0.1, in: 0...1) - 0.3) < 0.0001)
        #expect(UnitConversion.snap(5, toStep: 0.5, in: 0...2) == 2)
        #expect(UnitConversion.snap(-1, toStep: 0, in: 0...2) == 0)
    }

    @Test func temperatureConversionsRoundTrip() {
        #expect(UnitConversion.celsiusToFahrenheit(100) == 212)
        #expect(abs(UnitConversion.fahrenheitToCelsius(UnitConversion.celsiusToFahrenheit(21.5)) - 21.5) < 0.0001)
    }

    @Test func intakeAdditionsEmptiness() {
        #expect(IntakeAdditions.none.isEmpty)
        #expect(!IntakeAdditions(caffeineMg: 10).isEmpty)
        var additions = IntakeAdditions(waterLiters: 0.33)
        additions.snapWater(useMetricUnits: true)
        #expect(abs(additions.waterLiters - 0.3) < 0.0001)
    }

    @Test func reviewMilestonePromptsOnceOnFifth() {
        #expect(ReviewMilestone.shouldPrompt(totalMigraines: 5, hasPrompted: false))
        #expect(!ReviewMilestone.shouldPrompt(totalMigraines: 5, hasPrompted: true))
        #expect(!ReviewMilestone.shouldPrompt(totalMigraines: 4, hasPrompted: false))
        #expect(!ReviewMilestone.shouldPrompt(totalMigraines: 6, hasPrompted: false))
    }

    @Test func onboardingStepsAdvanceInOrderAndStopAtTheEnd() {
        #expect(OnboardingStep.privacy.next == .location)
        #expect(OnboardingStep.user.next == .complete)
        #expect(OnboardingStep.complete.next == nil)
        #expect(OnboardingStep.location.isSkippable)
        #expect(!OnboardingStep.health.isSkippable)
    }

    @Test func triggerCatalogCoversEveryCaseExactlyOnce() {
        let grouped = MigraineTrigger.grouped.flatMap(\.items)
        #expect(Set(grouped).count == MigraineTrigger.allCases.count)
        #expect(grouped.count == MigraineTrigger.allCases.count)
        for trigger in MigraineTrigger.allCases {
            #expect(trigger.group.triggers.contains(trigger))
        }
    }

    @Test func triggerSearchFiltersByDisplayName() {
        #expect(MigraineTrigger.triggers(in: .dietaryHydration, matching: "wine") == [.alcoholRedWine])
        #expect(MigraineTrigger.triggers(in: .sensory, matching: "  ") == MigraineTrigger.Group.sensory.triggers)
    }

    @Test func severityBuckets() {
        #expect(Severity.from(painLevel: 0) == .low)
        #expect(Severity.from(painLevel: 3) == .low)
        #expect(Severity.from(painLevel: 4) == .medium)
        #expect(Severity.from(painLevel: 6) == .medium)
        #expect(Severity.from(painLevel: 7) == .high)
        #expect(Severity.high.text(for: 9) == "High (9)")
    }

    @Test func skyConditionRawValuesMatchWeatherKitCaseNames() {
        // The persisted attribute stores the raw value; these must never drift.
        #expect(SkyCondition.strongStorms.rawValue == "strongStorms")
        #expect(SkyCondition.partlyCloudy.rawValue == "partlyCloudy")
        #expect(SkyCondition(rawValue: "wintryMix") == .wintryMix)
        #expect(SkyCondition.allCases.count == 34)
    }

    @Test func dashboardStatDefaults() {
        #expect(DashboardStat.water.defaultVisibility)
        #expect(!DashboardStat.steps.defaultVisibility)
        #expect(DashboardStat.healthKitStats.count + DashboardStat.insightStats.count == DashboardStat.allCases.count)
    }

    @Test func uniquedKeepsFirstOccurrence() {
        #expect(["a", "B", "A", "b", "c"].uniqued { $0.lowercased() } == ["a", "B", "c"])
        #expect([3, 1, 3, 2, 1].uniqued() == [3, 1, 2])
    }

    @Test func movingReordersLikeSwiftUI() {
        #expect(["A", "B", "C"].moving(fromOffsets: IndexSet(integer: 0), toOffset: 3) == ["B", "C", "A"])
        #expect(["A", "B", "C"].moving(fromOffsets: IndexSet(integer: 2), toOffset: 0) == ["C", "A", "B"])
    }

    @Test func dateFormattingHonorsFieldOrder() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2025, month: 8, day: 28, hour: 15, minute: 41))!
        let locale = Locale(identifier: "en_US")
        // Formatters use the current time zone; compare the date portion only.
        #expect(DateFormatting.date(date, useDMY: true, locale: locale).hasPrefix("28 Aug 2025") || DateFormatting.date(date, useDMY: true, locale: locale).hasPrefix("27 Aug 2025"))
        #expect(DateFormatting.date(date, useDMY: false, locale: locale).hasPrefix("Aug 2"))
    }
}
