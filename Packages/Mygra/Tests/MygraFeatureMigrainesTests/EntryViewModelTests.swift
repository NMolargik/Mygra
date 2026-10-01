//
//  EntryViewModelTests.swift
//  MygraFeatureMigrainesTests
//
//  The entry form's pure logic: validation, custom triggers, food parsing, record
//  assembly, and the modify sheet's timing validation. (Views are iOS-only; these run
//  on the host.)
//

#if os(iOS)
import Foundation
import Testing
import MygraCore
@testable import MygraFeatureMigraines

@Suite("MigraineEntryView.ViewModel")
@MainActor
struct EntryViewModelTests {
    @Test func validationRejectsEndBeforeStart() {
        let vm = MigraineEntryView.ViewModel()
        vm.isOngoing = false
        vm.startDate = Date()
        vm.endDate = vm.startDate.addingTimeInterval(-60)
        #expect(!vm.validateBeforeSave())
        #expect(vm.showValidationAlert)
        vm.endDate = vm.startDate.addingTimeInterval(60)
        #expect(vm.validateBeforeSave())
    }

    @Test func customTriggersAreTitleCasedAndUnique() {
        let vm = MigraineEntryView.ViewModel()
        vm.customTriggerInput = "  red wine "
        vm.addCustomTrigger()
        vm.customTriggerInput = "RED WINE"
        vm.addCustomTrigger()
        #expect(vm.customTriggers == ["Red Wine"])
        #expect(vm.customTriggerInput.isEmpty)
        vm.removeCustomTrigger(at: 5)
        vm.removeCustomTrigger(at: 0)
        #expect(vm.customTriggers.isEmpty)
    }

    @Test func foodsSplitOnCommasAndNewlines() {
        let vm = MigraineEntryView.ViewModel()
        vm.foodsText = "Coffee, cheese\n chocolate ,,"
        #expect(vm.parsedFoods == ["Coffee", "cheese", "chocolate"])
    }

    @Test func buildMigraineAssemblesTheForm() {
        let vm = MigraineEntryView.ViewModel()
        vm.painLevel = 8
        vm.stressLevel = 2
        vm.pinned = true
        vm.isOngoing = false
        vm.endDate = vm.startDate.addingTimeInterval(3600)
        vm.selectedTriggers = [.stress]
        vm.customTriggers = ["Deadline"]
        vm.noteText = "   "
        let health = HealthData(sleepHours: 5)
        let migraine = vm.buildMigraine(health: health, weather: nil)
        #expect(migraine.painLevel == 8)
        #expect(migraine.isPinned)
        #expect(migraine.endDate == vm.endDate)
        #expect(migraine.triggers == [.stress])
        #expect(migraine.customTriggers == ["Deadline"])
        #expect(migraine.note == nil)
        #expect(migraine.health === health)
        #expect(migraine.weather == nil)
    }
}

@Suite("MigraineEdits validation")
struct MigraineEditsTests {
    @Test func rejectsFutureAndInvertedTimes() {
        let now = Date()
        #expect(MigraineEdits.validationMessage(startDate: now.addingTimeInterval(60), endDate: nil, now: now) != nil)
        #expect(MigraineEdits.validationMessage(startDate: now.addingTimeInterval(-60), endDate: now.addingTimeInterval(-120), now: now) != nil)
        #expect(MigraineEdits.validationMessage(startDate: now.addingTimeInterval(-60), endDate: now.addingTimeInterval(60), now: now) != nil)
        #expect(MigraineEdits.validationMessage(startDate: now.addingTimeInterval(-60), endDate: now.addingTimeInterval(-30), now: now) == nil)
        #expect(MigraineEdits.validationMessage(startDate: now.addingTimeInterval(-60), endDate: nil, now: now) == nil)
    }
}
#else
import Testing

@Suite("MygraFeatureMigraines module") struct MygraFeatureMigrainesHostPlaceholder {
    @Test func viewsAreiOSOnly() { #expect(true) }
}
#endif
