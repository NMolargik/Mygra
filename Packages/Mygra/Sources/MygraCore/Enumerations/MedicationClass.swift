//
//  MedicationClass.swift
//  MygraCore
//
//  Acute-medication classes as headache clinics group them, with the monthly-use limits
//  from ICHD-3 for medication-overuse headache: ergots, triptans, opioids, and
//  combination analgesics at 10 or more days a month; simple analgesics at 15 or more.
//  Raw values are persisted (and mirrored in `MedicationDose.classRaw`): never rename a case.
//

import Foundation

nonisolated public enum MedicationClass: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case triptan
    case simpleAnalgesic
    case combinationAnalgesic
    case opioid
    case gepant
    case ergot
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .triptan: String(localized: "Triptan")
        case .simpleAnalgesic: String(localized: "Simple analgesic")
        case .combinationAnalgesic: String(localized: "Combination analgesic")
        case .opioid: String(localized: "Opioid")
        case .gepant: String(localized: "Gepant")
        case .ergot: String(localized: "Ergot")
        case .other: String(localized: "Other")
        }
    }

    /// Plural form used in sentences ("triptans").
    public var pluralName: String {
        switch self {
        case .triptan: String(localized: "triptans")
        case .simpleAnalgesic: String(localized: "simple analgesics")
        case .combinationAnalgesic: String(localized: "combination analgesics")
        case .opioid: String(localized: "opioids")
        case .gepant: String(localized: "gepants")
        case .ergot: String(localized: "ergots")
        case .other: String(localized: "other medications")
        }
    }

    public var examples: String {
        switch self {
        case .triptan: String(localized: "Sumatriptan, rizatriptan")
        case .simpleAnalgesic: String(localized: "Ibuprofen, naproxen, acetaminophen")
        case .combinationAnalgesic: String(localized: "Acetaminophen-aspirin-caffeine, butalbital combinations")
        case .opioid: String(localized: "Codeine, tramadol")
        case .gepant: String(localized: "Ubrogepant, rimegepant")
        case .ergot: String(localized: "Dihydroergotamine, ergotamine")
        case .other: String(localized: "Anything else you take for an attack")
        }
    }

    /// Days per month at which regular use counts as medication overuse, or nil when
    /// there is no established limit (gepants, other).
    public var overuseThresholdDays: Int? {
        switch self {
        case .triptan, .combinationAnalgesic, .opioid, .ergot: 10
        case .simpleAnalgesic: 15
        case .gepant, .other: nil
        }
    }

    public init(storedValue: String) {
        self = MedicationClass(rawValue: storedValue) ?? .other
    }
}

/// Common acute medications offered as one-tap choices in quick-add.
nonisolated public struct MedicationPreset: Identifiable, Hashable, Sendable {
    public let name: String
    public let medicationClass: MedicationClass
    public var id: String { "\(medicationClass.rawValue)|\(name)" }

    public static let all: [MedicationPreset] = [
        .init(name: "Sumatriptan", medicationClass: .triptan),
        .init(name: "Rizatriptan", medicationClass: .triptan),
        .init(name: "Eletriptan", medicationClass: .triptan),
        .init(name: "Zolmitriptan", medicationClass: .triptan),
        .init(name: "Ibuprofen", medicationClass: .simpleAnalgesic),
        .init(name: "Naproxen", medicationClass: .simpleAnalgesic),
        .init(name: "Acetaminophen", medicationClass: .simpleAnalgesic),
        .init(name: "Aspirin", medicationClass: .simpleAnalgesic),
        .init(name: "Excedrin Migraine", medicationClass: .combinationAnalgesic),
        .init(name: "Butalbital combination", medicationClass: .combinationAnalgesic),
        .init(name: "Codeine", medicationClass: .opioid),
        .init(name: "Tramadol", medicationClass: .opioid),
        .init(name: "Ubrogepant", medicationClass: .gepant),
        .init(name: "Rimegepant", medicationClass: .gepant),
        .init(name: "Dihydroergotamine", medicationClass: .ergot),
    ]

    public static func presets(for medicationClass: MedicationClass) -> [MedicationPreset] {
        all.filter { $0.medicationClass == medicationClass }
    }
}
