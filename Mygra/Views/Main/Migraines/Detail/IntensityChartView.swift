//
//  IntensityChartView.swift
//  Mygra
//
//  Created by Nick Molargik on 1/16/26.
//

import SwiftUI
import Charts

/// A chart showing pain and stress intensity over the duration of a migraine.
struct IntensityChartView: View {
    let samples: [IntensitySample]
    let startDate: Date
    let endDate: Date?
    /// Optional callback for updating intensity. When provided, shows an "Update" button in the header.
    var onUpdateIntensity: (() -> Void)? = nil

    private var sortedSamples: [IntensitySample] {
        samples.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Label("Intensity Over Time", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                Spacer()
                if let onUpdateIntensity {
                    Button {
                        onUpdateIntensity()
                    } label: {
                        Label("Update", systemImage: "waveform.path.ecg")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.mygraPurple)
                }
            }

            if sortedSamples.isEmpty {
                // Empty state
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("No intensity samples recorded yet")
                )
                .frame(height: 150)
            } else if sortedSamples.count == 1 {
                // Single point - show values without a chart
                singleSampleView
            } else {
                // Chart with multiple points
                chartView
            }

            // Legend
            HStack(spacing: 16) {
                LegendItem(color: .red, label: "Pain")
                LegendItem(color: .indigo, label: "Stress")
            }
            .font(.caption)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var singleSampleView: some View {
        let sample = sortedSamples[0]
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(sample.painLevel)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Stress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(sample.stressLevel)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.indigo)
            }

            Spacer()

            Text("at start")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var chartView: some View {
        Chart {
            ForEach(sortedSamples) { sample in
                // Pain line
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Pain", sample.painLevel),
                    series: .value("Type", "Pain")
                )
                .foregroundStyle(.red)
                .symbol(Circle())
                .interpolationMethod(.monotone)

                // Stress line
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Stress", sample.stressLevel),
                    series: .value("Type", "Stress")
                )
                .foregroundStyle(.indigo)
                .symbol(Square())
                .interpolationMethod(.monotone)
            }
        }
        .chartYScale(domain: 0...10)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 5, 10]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .frame(height: 180)
    }
}

// MARK: - Legend Item

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Square Shape for Chart Symbol

private struct Square: ChartSymbolShape {
    var perceptualUnitRect: CGRect {
        CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1))
    }
}

#Preview("Intensity Chart - Multiple Samples") {
    IntensityChartView(
        samples: [],
        startDate: Date(),
        endDate: nil
    )
    .padding()
}
