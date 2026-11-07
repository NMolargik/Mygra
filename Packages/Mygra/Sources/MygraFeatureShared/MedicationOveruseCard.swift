//
//  MedicationOveruseCard.swift
//  MygraFeatureShared
//
//  The in-app medication-overuse warning: one row per class at 8+ days (approaching) or
//  at its 10/15-day threshold in the last 30 days. Free for everyone. Informational,
//  with a link to the American Migraine Foundation's guidance.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

public struct MedicationOveruseCard: View {
    @Environment(MigraineDataModel.self) private var migraineData

    public init() {}

    public var body: some View {
        let alerts = migraineData.overuseAlerts()
        if !alerts.isEmpty {
            InsightCard(title: String(localized: "Medication Use"), systemImage: "pills.fill", accent: alerts.contains { $0.status == .threshold } ? .red : .orange) {
                VStack(alignment: .leading, spacing: Brand.Space.md) {
                    ForEach(alerts) { alert in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(alert.title, systemImage: alert.status == .threshold ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(alert.status == .threshold ? Color.red : Color.orange)
                            Text(alert.message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Link(destination: MedicationOveruse.guidanceURL) {
                        Label("American Migraine Foundation: medication-overuse headache", systemImage: "arrow.up.right.square")
                            .font(.footnote.weight(.semibold))
                    }
                    .accessibilityHint("Opens in your browser")
                }
            }
        }
    }
}
#endif
