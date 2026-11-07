//
//  MedicationDose.swift
//  MygraCore
//
//  One acute-medication dose taken for an attack: name, class, dose, and when. CloudKit
//  rules: defaults on every attribute, optional relationship, no unique constraints.
//  The class is stored as its raw string so a future class never breaks decoding.
//

import Foundation
import SwiftData

@Model
public final class MedicationDose {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()

    /// What was taken ("Sumatriptan").
    public var name: String = ""
    /// `MedicationClass` raw value.
    public var classRaw: String = MedicationClass.other.rawValue
    /// Free-form dose ("50 mg", "2 tablets"); empty when not recorded.
    public var dose: String = ""
    /// When it was taken.
    public var takenAt: Date = Date()

    /// The attack this dose was taken for.
    public var migraine: Migraine?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        name: String,
        medicationClass: MedicationClass,
        dose: String = "",
        takenAt: Date = Date(),
        migraine: Migraine? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.classRaw = medicationClass.rawValue
        self.dose = dose
        self.takenAt = takenAt
        self.migraine = migraine
    }

    public var medicationClass: MedicationClass {
        get { MedicationClass(storedValue: classRaw) }
        set { classRaw = newValue.rawValue }
    }

    /// "Sumatriptan · 50 mg"
    public var summary: String {
        dose.isEmpty ? name : "\(name) · \(dose)"
    }
}
