//
//  AttackMode.swift
//  MygraCore
//
//  Pure logic behind Attack Mode, the one-tap, near-dark logging surface for a severe
//  migraine: the big intensity steps, the quick-medication suggestions, the dim palette
//  tokens (so "nothing bright" is a tested guarantee), the start/active/end state
//  machine, and the deferred "finish logging" policy. Views, notifications, and
//  persistence live elsewhere; everything here is host-tested.
//

import Foundation

// MARK: - Intensity steps

/// The big pain steps offered during an attack. Five coarse levels beat a 0 to 10 slider
/// when the screen is the last thing you want to look at.
nonisolated public enum AttackIntensity {
    public static let levels: [Int] = [2, 4, 6, 8, 10]

    /// The step closest to a stored 0 to 10 pain level (ties round up).
    public static func nearestLevel(to painLevel: Int) -> Int {
        let clamped = min(10, max(0, painLevel))
        return levels.min { lhs, rhs in
            let l = abs(lhs - clamped), r = abs(rhs - clamped)
            return l == r ? lhs > rhs : l < r
        } ?? 6
    }

    public static func label(for level: Int) -> String {
        switch nearestLevel(to: level) {
        case 2: return String(localized: "Mild")
        case 4: return String(localized: "Moderate")
        case 6: return String(localized: "Strong")
        case 8: return String(localized: "Severe")
        default: return String(localized: "Worst")
        }
    }
}

// MARK: - Palette tokens

/// A color as plain 0 to 1 components, so the design system and the watch app can each
/// build a `Color` while the "dim, warm, low-saturation" rules are tested once here.
nonisolated public struct AttackRGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// WCAG relative luminance.
    public var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    public var brightestChannel: Double { max(red, green, blue) }

    /// HSV saturation.
    public var saturation: Double {
        let top = brightestChannel
        return top == 0 ? 0 : (top - min(red, green, blue)) / top
    }

    /// WCAG contrast ratio against another color.
    public func contrast(with other: AttackRGB) -> Double {
        let a = luminance, b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

nonisolated public enum AttackPalette {
    public static let background = AttackRGB(0.02, 0.012, 0.01)
    /// Main text: dim amber.
    public static let primaryText = AttackRGB(0.70, 0.46, 0.33)
    /// Hints and captions: dimmer, redder.
    public static let secondaryText = AttackRGB(0.56, 0.37, 0.29)
    public static let buttonFill = AttackRGB(0.085, 0.05, 0.04)
    public static let buttonFillSelected = AttackRGB(0.20, 0.105, 0.075)
    public static let border = AttackRGB(0.20, 0.115, 0.085)
    public static let endText = AttackRGB(0.75, 0.42, 0.35)
    public static let endFill = AttackRGB(0.12, 0.05, 0.04)
    /// A black veil laid over the whole screen to dim the app's own UI further. The app
    /// never touches system brightness.
    public static let dimOverlayOpacity: Double = 0.18

    public static var allTokens: [AttackRGB] {
        [background, primaryText, secondaryText, buttonFill, buttonFillSelected, border, endText, endFill]
    }
}

// MARK: - Quick medications

/// A medication the user can log in one tap: name, class, and the dose they usually take.
nonisolated public struct QuickMedication: Codable, Hashable, Sendable, Identifiable {
    public var name: String
    public var classRaw: String
    public var dose: String

    public var id: String { "\(classRaw)|\(name.lowercased())|\(dose.lowercased())" }

    public init(name: String, medicationClass: MedicationClass, dose: String = "") {
        self.name = name
        self.classRaw = medicationClass.rawValue
        self.dose = dose
    }

    public init(name: String, classRaw: String, dose: String) {
        self.name = name
        self.classRaw = classRaw
        self.dose = dose
    }

    public var medicationClass: MedicationClass { MedicationClass(storedValue: classRaw) }

    /// "Sumatriptan 50 mg" (or just the name when no dose is recorded).
    public var label: String { dose.isEmpty ? name : "\(name) \(dose)" }

    // MARK: Wire form

    public var payload: [String: String] {
        ["name": name, "class": classRaw, "dose": dose]
    }

    public init?(payload: [String: Any]) {
        guard let name = payload["name"] as? String, !name.isEmpty else { return nil }
        self.init(name: name, classRaw: payload["class"] as? String ?? MedicationClass.other.rawValue, dose: payload["dose"] as? String ?? "")
    }
}

public enum QuickMedications {
    /// Fallback shown before any dose has been logged.
    private static let starters: [QuickMedication] = [
        QuickMedication(name: "Ibuprofen", medicationClass: .simpleAnalgesic),
        QuickMedication(name: "Acetaminophen", medicationClass: .simpleAnalgesic),
        QuickMedication(name: "Sumatriptan", medicationClass: .triptan),
    ]

    /// The user's usual medications: the most-used (name, dose) pairs from past doses,
    /// ties broken by recency. Falls back to a few common choices when there is no history.
    public static func suggestions(from doses: [MedicationDose], limit: Int = 4) -> [QuickMedication] {
        struct Tally { var medication: QuickMedication; var count = 0; var latest = Date.distantPast }
        var tallies: [String: Tally] = [:]
        for dose in doses {
            let name = dose.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let candidate = QuickMedication(name: name, medicationClass: dose.medicationClass, dose: dose.dose.trimmingCharacters(in: .whitespacesAndNewlines))
            var tally = tallies[candidate.id] ?? Tally(medication: candidate)
            tally.count += 1
            if dose.takenAt > tally.latest {
                tally.latest = dose.takenAt
                tally.medication = candidate
            }
            tallies[candidate.id] = tally
        }
        let ranked = tallies.values.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            if $0.latest != $1.latest { return $0.latest > $1.latest }
            return $0.medication.label < $1.medication.label
        }
        let picked = ranked.prefix(limit).map(\.medication)
        return picked.isEmpty ? Array(starters.prefix(limit)) : Array(picked)
    }
}

// MARK: - State machine

nonisolated public enum AttackPhase: Equatable, Sendable {
    case idle
    case active(id: UUID, startedAt: Date)

    public var activeID: UUID? {
        if case .active(let id, _) = self { return id }
        return nil
    }
}

/// What an entry point (Watch, widget, control, Action button, Siri) should do.
nonisolated public enum AttackEntry: Equatable, Sendable {
    case startNew
    case openExisting(UUID)

    /// Starting while an attack is already active opens it instead of starting a second.
    public static func resolve(ongoingID: UUID?) -> AttackEntry {
        ongoingID.map(AttackEntry.openExisting) ?? .startNew
    }
}

nonisolated public enum AttackEvent: Equatable, Sendable {
    /// An attack was started (or an entry point resolved to an existing one).
    case start(id: UUID, at: Date)
    /// The user tapped End Attack.
    case end(at: Date)
    /// The store changed underneath us: the ongoing migraine, if any.
    case sync(ongoingID: UUID?, startedAt: Date?)
}

nonisolated public enum AttackEffect: Equatable, Sendable {
    case presentAttackMode
    case dismissAttackMode
    /// End Attack finished: hand the migraine to the deferred finish-logging prompt.
    case deferFinishLogging(id: UUID, endedAt: Date)
}

nonisolated public struct AttackStateMachine: Equatable, Sendable {
    public private(set) var phase: AttackPhase

    public init(phase: AttackPhase = .idle) { self.phase = phase }

    @discardableResult
    public mutating func apply(_ event: AttackEvent) -> [AttackEffect] {
        switch (phase, event) {
        case (.idle, .start(let id, let at)):
            phase = .active(id: id, startedAt: at)
            return [.presentAttackMode]

        case (.active, .start):
            // Never a second attack: surface the one in progress.
            return [.presentAttackMode]

        case (.active(let id, _), .end(let at)):
            phase = .idle
            return [.dismissAttackMode, .deferFinishLogging(id: id, endedAt: at)]

        case (.idle, .end):
            return []

        case (.idle, .sync(let ongoingID, let startedAt)):
            if let ongoingID { phase = .active(id: ongoingID, startedAt: startedAt ?? Date()) }
            return []

        case (.active(let current, _), .sync(let ongoingID, let startedAt)):
            if let ongoingID {
                if ongoingID != current { phase = .active(id: ongoingID, startedAt: startedAt ?? Date()) }
                return []
            }
            // Ended somewhere else (watch, Siri, the detail screen): no deferred prompt,
            // the user already used another flow.
            phase = .idle
            return [.dismissAttackMode]
        }
    }
}

// MARK: - Deferred finish-logging policy

nonisolated public struct FinishLoggingSettings: Equatable, Sendable {
    public static let defaultDelayMinutes = 120
    public static let delayOptions: [Int] = [30, 60, 120, 240, 480]

    public var isEnabled: Bool
    public var delayMinutes: Int

    public init(isEnabled: Bool = true, delayMinutes: Int = FinishLoggingSettings.defaultDelayMinutes) {
        self.isEnabled = isEnabled
        self.delayMinutes = min(24 * 60, max(1, delayMinutes))
    }

    /// Reads the user's choice; "never set" means enabled with the 2 hour default.
    public init(defaults: (any KeyValueStoring)?) {
        let enabled = (defaults?.object(forKey: AppStorageKeys.attackFinishPromptEnabled) as? Bool) ?? true
        let stored = defaults?.object(forKey: AppStorageKeys.attackFinishPromptDelayMinutes) as? Int
        self.init(isEnabled: enabled, delayMinutes: stored ?? Self.defaultDelayMinutes)
    }

    public var delay: TimeInterval { TimeInterval(delayMinutes * 60) }
}

nonisolated public struct FinishLoggingPlan: Equatable, Sendable {
    /// When the gentle notification fires.
    public let fireDate: Date
    /// The in-app card shows right away and stays until handled.
    public let showsCard: Bool
}

nonisolated public enum FinishLoggingPlanner {
    /// Nothing is planned when the user turned the prompt off. A late-arriving end
    /// (for example relayed from the watch) never schedules into the past.
    public static func plan(endedAt: Date, now: Date = Date(), settings: FinishLoggingSettings) -> FinishLoggingPlan? {
        guard settings.isEnabled else { return nil }
        let fire = max(endedAt.addingTimeInterval(settings.delay), now.addingTimeInterval(5))
        return FinishLoggingPlan(fireDate: fire, showsCard: true)
    }
}

/// An ended attack waiting for its deferred questions.
nonisolated public struct FinishItem: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let endedAt: Date
    public let dueDate: Date

    public init(id: UUID, endedAt: Date, dueDate: Date) {
        self.id = id
        self.endedAt = endedAt
        self.dueDate = dueDate
    }
}
