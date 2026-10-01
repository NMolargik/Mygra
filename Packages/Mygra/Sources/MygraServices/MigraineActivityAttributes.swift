//
//  MigraineActivityAttributes.swift
//  MygraServices
//
//  The ongoing-migraine Live Activity attributes, linked by both the app (which starts
//  and updates the activity) and the widget extension (which renders it).
//

#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
import Foundation

// nonisolated: ActivityKit encodes and observes these off the main actor.
nonisolated public struct MigraineActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let migraineID: UUID
        public let startDate: Date
        /// Pain level (0-10).
        public let severity: Int
        /// Stress level (0-10).
        public let stressLevel: Int
        /// Optional short notes or triggers for context.
        public let notes: String?

        public init(migraineID: UUID, startDate: Date, severity: Int, stressLevel: Int, notes: String?) {
            self.migraineID = migraineID
            self.startDate = startDate
            self.severity = severity
            self.stressLevel = stressLevel
            self.notes = notes
        }
    }

    public init() {}
}

#if DEBUG
extension MigraineActivityAttributes.ContentState {
    public static var sample: MigraineActivityAttributes.ContentState {
        .init(migraineID: UUID(), startDate: Date().addingTimeInterval(-3600), severity: 7, stressLevel: 5, notes: "Triggered by stress")
    }
}
#endif
#endif
