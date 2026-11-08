//
//  PressureDrop.swift
//  MygraCore
//
//  Pure barometric-pressure drop detection over an hourly series (past readings plus
//  forecast). A drop is "at least N hPa lower than the highest reading in the previous
//  M hours". The user tunes N and M; the defaults mirror the existing low-pressure risk
//  rule (1013 to 1008 hPa is 5 hPa).
//

import Foundation

nonisolated public struct PressureSample: Equatable, Sendable, Identifiable {
    public let date: Date
    public let hpa: Double
    public var id: Date { date }

    public init(date: Date, hpa: Double) {
        self.date = date
        self.hpa = hpa
    }
}

/// How far, how fast: a fall of `dropHpa` or more within `windowHours`.
nonisolated public struct PressureDropThreshold: Equatable, Sendable {
    public var dropHpa: Double
    public var windowHours: Int

    public static let dropRange: ClosedRange<Double> = 2...12
    public static let windowOptions = [3, 6, 12, 24]
    public static let `default` = PressureDropThreshold(dropHpa: 5, windowHours: 12)

    public init(dropHpa: Double, windowHours: Int) {
        self.dropHpa = min(max(dropHpa.rounded(), Self.dropRange.lowerBound), Self.dropRange.upperBound)
        self.windowHours = Self.windowOptions.contains(windowHours) ? windowHours : Self.default.windowHours
    }
}

/// One fall: the pressure peak it began at through the last reading that met the threshold.
nonisolated public struct PressureDrop: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let fromHpa: Double
    public let toHpa: Double
    public var dropHpa: Double { fromHpa - toHpa }

    public init(start: Date, end: Date, fromHpa: Double, toHpa: Double) {
        self.start = start
        self.end = end
        self.fromHpa = fromHpa
        self.toHpa = toHpa
    }
}

nonisolated public enum PressureDropDetector {
    /// An alert covers a drop that finished up to this long ago or is forecast this soon.
    public static let lookBackHours = 3.0
    public static let lookAheadHours = 6.0
    /// An attack counts as following a drop when it began within this long after it ended.
    public static let attackAfterDropHours = 6.0

    public static func drops(in samples: [PressureSample], threshold: PressureDropThreshold) -> [PressureDrop] {
        let sorted = samples.sorted { $0.date < $1.date }
        let window = Double(threshold.windowHours) * 3600
        var episodes: [PressureDrop] = []

        for (index, sample) in sorted.enumerated() {
            // Highest earlier reading inside the window (the earliest wins a tie).
            var peak: PressureSample?
            for earlier in sorted[..<index].reversed() {
                if sample.date.timeIntervalSince(earlier.date) > window { break }
                if peak == nil || earlier.hpa >= peak!.hpa { peak = earlier }
            }
            guard let peak, peak.hpa - sample.hpa >= threshold.dropHpa - 1e-9 else { continue }

            if let last = episodes.last, peak.date <= last.end {
                // Same fall (windows overlap): extend it.
                episodes[episodes.count - 1] = PressureDrop(
                    start: last.start,
                    end: sample.date,
                    fromHpa: max(last.fromHpa, peak.hpa),
                    toHpa: min(last.toHpa, sample.hpa)
                )
            } else {
                episodes.append(PressureDrop(start: peak.date, end: sample.date, fromHpa: peak.hpa, toHpa: sample.hpa))
            }
        }
        return episodes
    }

    /// The largest drop that is under way, just finished, or forecast soon; nil when none.
    public static func alertDrop(in drops: [PressureDrop], now: Date) -> PressureDrop? {
        let earliestEnd = now.addingTimeInterval(-lookBackHours * 3600)
        let latestStart = now.addingTimeInterval(lookAheadHours * 3600)
        return drops
            .filter { $0.end >= earliestEnd && $0.start <= latestStart }
            .max { $0.dropHpa < $1.dropHpa }
    }

    /// How many of the attack start times fall during a drop or shortly after it.
    public static func attacksFollowingDrops(_ attackStarts: [Date], drops: [PressureDrop]) -> Int {
        attackStarts.filter { start in
            drops.contains { start >= $0.start && start <= $0.end.addingTimeInterval(attackAfterDropHours * 3600) }
        }.count
    }

    // MARK: - Wording

    public static func explanation(_ threshold: PressureDropThreshold, useMetricUnits: Bool) -> String {
        String(localized: "Mygra flags a pressure drop when the pressure falls \(displayDrop(threshold.dropHpa, useMetricUnits: useMetricUnits)) or more within \(threshold.windowHours) hours. When one is happening or forecast in the next few hours, your weather-risk alert can fire. Lower numbers flag more drops.")
    }

    public static func displayDrop(_ hpa: Double, useMetricUnits: Bool) -> String {
        useMetricUnits
            ? String(format: "%.0f hPa", hpa)
            : String(format: "%.2f inHg", hpa * UnitConversion.hectopascalsToInchesOfMercury)
    }

    public static func alertDetail(_ drop: PressureDrop, useMetricUnits: Bool) -> String {
        String(localized: "Pressure is falling \(displayDrop(drop.dropHpa, useMetricUnits: useMetricUnits)) (\(Int(drop.fromHpa.rounded())) to \(Int(drop.toHpa.rounded())) hPa).")
    }
}

/// Persists the user's threshold in `KeyValueStoring`.
nonisolated public struct PressureDropThresholdStore {
    private let defaults: any KeyValueStoring

    public init(defaults: any KeyValueStoring) { self.defaults = defaults }

    public func load() -> PressureDropThreshold {
        guard defaults.object(forKey: AppStorageKeys.pressureDropThresholdHpa) != nil else { return .default }
        return PressureDropThreshold(
            dropHpa: defaults.double(forKey: AppStorageKeys.pressureDropThresholdHpa),
            windowHours: defaults.integer(forKey: AppStorageKeys.pressureDropWindowHours)
        )
    }

    public func save(_ threshold: PressureDropThreshold) {
        defaults.set(threshold.dropHpa, forKey: AppStorageKeys.pressureDropThresholdHpa)
        defaults.set(threshold.windowHours, forKey: AppStorageKeys.pressureDropWindowHours)
    }
}

/// How much of the series the pressure graph shows around "now".
nonisolated public enum PressureGraphRange: String, CaseIterable, Identifiable, Sendable {
    /// 48 hours back and 24 ahead: the 72-hour view.
    case threeDays
    /// 7 days back and 48 hours ahead, for tuning against more attacks.
    case week

    public var id: String { rawValue }
    public var hoursBack: Int { self == .threeDays ? 48 : 168 }
    public var hoursAhead: Int { self == .threeDays ? 24 : 48 }

    public func interval(now: Date) -> DateInterval {
        DateInterval(start: now.addingTimeInterval(-Double(hoursBack) * 3600), end: now.addingTimeInterval(Double(hoursAhead) * 3600))
    }

    public func samples(_ samples: [PressureSample], now: Date) -> [PressureSample] {
        let window = interval(now: now)
        return samples.filter { window.contains($0.date) }.sorted { $0.date < $1.date }
    }
}
