//
//  InsightsView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var migraines: [Migraine]

    // Define grid layout for widgets
    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    // Widget 1: Migraine Frequency
                    VStack {
                        Text("Migraine Frequency")
                            .font(.headline)
                        Text("\(migraines.count) migraines logged")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 2)

                    // Widget 2: Top Trigger
                    VStack {
                        Text("Top Trigger")
                            .font(.headline)
                        Text(calculateTopTrigger())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 2)

                    // Widget 3: Severity Breakdown
                    VStack {
                        Text("Severity Breakdown")
                            .font(.headline)
                        Text(calculateSeverityBreakdown())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 2)

                    // Widget 4: Hydration Correlation
                    VStack {
                        Text("Hydration Correlation")
                            .font(.headline)
                        Text(calculateHydrationCorrelation())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 2)

                    // Widget 5: Weather Widget
                    WeatherWidgetView()
                }
                .padding()
            }
            .navigationTitle("Mygra")
        }
    }

    // Placeholder function for top trigger
    private func calculateTopTrigger() -> String {
            let triggerCounts = migraines.flatMap { $0.triggerFoodsConsumed?.map(\.name) ?? [] }
                .reduce(into: [String: Int]()) { counts, trigger in
                    counts[trigger, default: 0] += 1
                }
            if let topTrigger = triggerCounts.max(by: { $0.value < $1.value }) {
                return "\(topTrigger.key) (\(topTrigger.value) times)"
            }
            return "No triggers logged"
        }

    // Placeholder function for severity breakdown
    private func calculateSeverityBreakdown() -> String {
        let severityCounts = migraines.reduce(into: [Migraine.Severity: Int]()) { counts, migraine in
            if let severity = migraine.severity {
                counts[severity, default: 0] += 1
            }
        }
        let breakdown = severityCounts.map { "\($0.key.rawValue): \($0.value)" }
            .joined(separator: ", ")
        return breakdown.isEmpty ? "No severity data" : breakdown
    }

    // Placeholder function for hydration correlation
    private func calculateHydrationCorrelation() -> String {
        let lowHydrationMigraines = migraines.filter { ($0.waterConsumed ?? 0) < 2.0 }.count
        let total = migraines.count
        return total > 0 ? "\(lowHydrationMigraines) of \(total) migraines with low hydration" : "No hydration data"
    }
}

#Preview {
    InsightsView()
}
