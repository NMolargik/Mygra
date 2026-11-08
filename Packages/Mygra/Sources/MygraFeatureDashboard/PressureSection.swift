//
//  PressureSection.swift
//  MygraFeatureDashboard
//
//  The barometric-pressure section inside the weather card (collapsed to one line): recent readings and the forecast
//  from the weather provider, flagged drops shaded, and the user's past attacks marked so
//  the personal threshold can be tuned. The threshold also drives the weather-risk alert.
//  A Mygra Plus feature (weather-risk forecasts); free users see the plain weather card.
//

#if os(iOS)
import SwiftUI
import Charts
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

struct PressureSection: View {
    let samples: [PressureSample]
    let attackStarts: [Date]
    var now: Date = Date()

    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false
    @AppStorage(AppStorageKeys.pressureDropThresholdHpa) private var dropHpa: Double = PressureDropThreshold.default.dropHpa
    @AppStorage(AppStorageKeys.pressureDropWindowHours) private var windowHours: Int = PressureDropThreshold.default.windowHours

    @State private var isExpanded = false
    @State private var range: PressureGraphRange = .threeDays
    #if DEBUG
    @State private var isTuning = UserDefaults.standard.bool(forKey: "MygraDebugTuning")
    #else
    @State private var isTuning = false
    #endif

    /// The one line shown while collapsed.
    private var collapsedSummary: String {
        guard samples.count >= 2 else { return String(localized: "Pressure trend loading") }
        if let drop = PressureDropDetector.alertDrop(in: drops, now: now) {
            return drop.start > now
                ? String(localized: "Pressure drop forecast: \(PressureDropDetector.displayDrop(drop.dropHpa, useMetricUnits: useMetricUnits))")
                : String(localized: "Pressure falling: \(PressureDropDetector.displayDrop(drop.dropHpa, useMetricUnits: useMetricUnits))")
        }
        return String(localized: "No pressure drop flagged for now")
    }

    private var threshold: PressureDropThreshold {
        PressureDropThreshold(dropHpa: dropHpa, windowHours: windowHours)
    }

    /// Drops are found over the whole series so a fall that began before the visible
    /// window still shows.
    private var drops: [PressureDrop] {
        PressureDropDetector.drops(in: samples, threshold: threshold)
    }

    private var visibleSamples: [PressureSample] { range.samples(samples, now: now) }

    private var visibleDrops: [PressureDrop] {
        let window = range.interval(now: now)
        return drops.filter { $0.end >= window.start && $0.start <= window.end }
    }

    private var visibleAttacks: [Date] {
        let window = range.interval(now: now)
        return attackStarts.filter { window.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            Button {
                Haptics.lightImpact()
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: Brand.Space.sm) {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundStyle(.mygraBlue)
                        .accessibilityHidden(true)
                    Text(collapsedSummary)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Hides the pressure graph" : "Shows the pressure graph and alert threshold")
            .accessibilityIdentifier("pressure.toggle")

            if isExpanded {
                Picker("Range", selection: $range) {
                    Text("3 days").tag(PressureGraphRange.threeDays)
                    Text("Week").tag(PressureGraphRange.week)
                }
                .pickerStyle(.segmented)

                if visibleSamples.count < 2 {
                    Text("Pressure history appears here once weather has loaded for your location.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    chart
                    legend
                    summary
                }
                thresholdSection
            }
        }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "MygraDebugPressureOpen") { isExpanded = true }
            #endif
        }
    }

    // MARK: - Chart

    private var chart: some View {
        let unit: Double = useMetricUnits ? 1 : UnitConversion.hectopascalsToInchesOfMercury
        let values = visibleSamples.map(\.hpa)
        let low = (values.min() ?? 1000) - 3
        let high = (values.max() ?? 1020) + 3
        return Chart {
            ForEach(visibleDrops, id: \.start) { drop in
                RectangleMark(
                    xStart: .value("Drop start", drop.start),
                    xEnd: .value("Drop end", drop.end),
                    yStart: .value("Low", low * unit),
                    yEnd: .value("High", high * unit)
                )
                .foregroundStyle(Color.orange.opacity(0.18))
            }

            ForEach(visibleSamples) { sample in
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("Pressure", sample.hpa * unit),
                    series: .value("Series", sample.date > now ? "Forecast" : "Recent")
                )
                .foregroundStyle(Color.mygraBlue)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: sample.date > now ? [4, 3] : []))
                .interpolationMethod(.monotone)
            }

            RuleMark(x: .value("Now", now))
                .foregroundStyle(.secondary.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    Text("Now").font(.caption2).foregroundStyle(.secondary)
                }

            ForEach(visibleAttacks, id: \.self) { start in
                RuleMark(x: .value("Attack", start))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartYScale(domain: (low * unit)...(high * unit))
        .chartXScale(domain: range.interval(now: now).start...range.interval(now: now).end)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(useMetricUnits ? "\(Int(number.rounded()))" : String(format: "%.1f", number))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: range == .threeDays ? .dateTime.weekday(.abbreviated).hour() : .dateTime.weekday(.abbreviated))
            }
        }
        .frame(height: 190)
        .accessibilityElement()
        .accessibilityLabel(Text("Barometric pressure graph"))
        .accessibilityValue(Text(summaryText))
    }

    private var legend: some View {
        HStack(spacing: Brand.Space.md) {
            LegendSwatch(color: .mygraBlue, label: useMetricUnits ? String(localized: "Pressure (hPa)") : String(localized: "Pressure (inHg)"))
            LegendSwatch(color: .orange.opacity(0.5), label: String(localized: "Flagged drop"))
            LegendSwatch(color: .red, label: String(localized: "Attack"))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Summary

    private var summaryText: String {
        let dropCount = visibleDrops.count
        let attacks = visibleAttacks.count
        let following = PressureDropDetector.attacksFollowingDrops(visibleAttacks, drops: drops)
        let dropsPart = dropCount == 1
            ? String(localized: "1 pressure drop flagged.")
            : String(localized: "\(dropCount) pressure drops flagged.")
        guard attacks > 0 else { return dropsPart }
        let attackPart = attacks == 1
            ? String(localized: "\(following) of 1 attack started during or within 6 hours after a flagged drop.")
            : String(localized: "\(following) of \(attacks) attacks started during or within 6 hours after a flagged drop.")
        return dropsPart + " " + attackPart
    }

    private var summary: some View {
        Text(summaryText)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Threshold

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: Brand.Space.md) {
            Button {
                Haptics.lightImpact()
                withAnimation(.snappy) { isTuning.toggle() }
            } label: {
                HStack {
                    Label("Alert threshold", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mygraPurple)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.mygraPurple)
                        .rotationEffect(.degrees(isTuning ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pressure.thresholdToggle")

            if isTuning {
                HStack {
                    Text("Drop size")
                    Spacer()
                    Text(verbatim: PressureDropDetector.displayDrop(threshold.dropHpa, useMetricUnits: useMetricUnits))
                        .monospacedDigit()
                        .foregroundStyle(Color.secondary)
                    Stepper("Drop size", value: $dropHpa, in: PressureDropThreshold.dropRange, step: 1)
                        .labelsHidden()
                        .accessibilityIdentifier("pressure.dropStepper")
                }

                Picker("Within", selection: $windowHours) {
                    ForEach(PressureDropThreshold.windowOptions, id: \.self) { hours in
                        Text("\(hours) hours").tag(hours)
                    }
                }
                .pickerStyle(.segmented)

                Text(PressureDropDetector.explanation(threshold, useMetricUnits: useMetricUnits))
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if threshold != .default {
                    Button("Reset to default") {
                        Haptics.lightImpact()
                        dropHpa = PressureDropThreshold.default.dropHpa
                        windowHours = PressureDropThreshold.default.windowHours
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
        }
    }
}

private struct LegendSwatch: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 6)
            Text(label)
        }
    }
}

#if DEBUG
#Preview("Pressure graph") {
    let now = Date()
    let samples = (-168...48).map { hour in
        PressureSample(date: now.addingTimeInterval(Double(hour) * 3600), hpa: 1013 + 6 * sin(Double(hour) / 14))
    }
    PressureSection(samples: samples, attackStarts: [now.addingTimeInterval(-20 * 3600)], now: now)
        .padding()
}
#endif
#endif
