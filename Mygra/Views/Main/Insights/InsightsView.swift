//
//  InsightsView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import WeatherKit

struct InsightsView: View {
    @Binding var showingEntrySheet: Bool

    @Environment(InsightManager.self) private var insightManager: InsightManager
    @Environment(HealthManager.self) private var healthManager: HealthManager
    @Environment(WeatherManager.self) private var weatherManager: WeatherManager
    @Environment(MigraineManager.self) private var migraineManager: MigraineManager

    @AppStorage("useMetricUnits") private var useMetricUnits: Bool = false
    
    // Intake editor state
    @State private var addWater: Double = 0        // liters
    @State private var addCaffeine: Double = 0     // mg
    @State private var addCalories: Double = 0     // kcal
    @State private var addSleepHours: Double = 0   // hours
    @State private var isSavingIntake: Bool = false
    @State private var intakeError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Weather widget directly under the navigation title
                    weatherCard
                    
                    // Today summary tiles
                    todaySummarySection

                    // Quick Log (HealthKit)
                    quickLogCard

                    // Insights section (cards)
                    insightsSection

                    // Recent migraines preview
                    recentMigrainesSection

                    // Spacer at bottom
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Mygra")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEntrySheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("New Migraine")
                                .bold()
                        }
                        .foregroundStyle(.blue)
                    }
                    .accessibilityIdentifier("addEntryButton")
                }
            }
            .refreshable {
                await refreshAll()
            }
            .task {
                await initialLoadIfNeeded()
            }
        }
    }

    // MARK: - Sections

    private var weatherCard: some View {
        Group {
            if let temp = weatherManager.temperatureString,
               let press = weatherManager.pressureString,
               let humid = weatherManager.humidityPercentString,
               let condition = weatherManager.condition {
                HStack(spacing: 12) {
                    // Symbol with color based on condition
                    Image(systemName: symbolName(for: condition))
                        .font(.system(size: 32))
                        .foregroundStyle(symbolColor(for: condition))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(conditionLabel(for: condition)) • \(temp)")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            Label(press, systemImage: "gauge.with.dots.needle.bottom.50percent")
                            Label(humid, systemImage: "humidity")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if let updated = weatherManager.lastUpdated {
                            Text(updated, style: .time)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if weatherManager.isFetching {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button {
                                Task { await weatherManager.refresh() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    if let error = weatherManager.error {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                                Text(error.localizedDescription).font(.footnote)
                                Spacer()
                            }
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .padding(6)
                        }
                    }
                }
            } else {
                // Empty/permission state
                HStack(spacing: 12) {
                    Image(systemName: "location")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weather Unavailable")
                            .font(.headline)
                        Text("Enable location and refresh to see current weather.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh") {
                        Task { await weatherManager.refresh() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var quickLogCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Quick Log", systemImage: "bolt.fill")
                    .font(.headline)
                Spacer()
                if !healthManager.isAuthorized {
                    Button("Connect Health") {
                        Task { await healthManager.requestAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button {
                        Task { await healthManager.refreshLatestForToday() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }

            IntakeEditorView(
                addWater: $addWater,
                addCaffeine: $addCaffeine,
                addCalories: $addCalories,
                addSleepHours: $addSleepHours,
                useMetricUnits: useMetricUnits,
                waterRange: useMetricUnits ? 0...2.5 : 0...(2.5 * 33.814 / 33.814), // slider in liters regardless; display handles unit
                waterStep: 0.1,
                waterDisplay: { liters in
                    if useMetricUnits {
                        return String(format: "+%.1f L", liters)
                    } else {
                        let oz = liters * 33.814
                        return String(format: "+%.0f oz", oz)
                    }
                },
                isSaving: isSavingIntake,
                errorMessage: intakeError,
                allAddsAreZero: allIntakeAddsAreZero,
                onAdd: { Task { await saveIntake() } },
                onCancel: { resetIntakeInputs() }
            )
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var todaySummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Today", systemImage: "calendar")
                    .font(.headline)
                Spacer()
            }

            if let data = healthManager.latestData {
                // Four tiles
                HStack(spacing: 12) {
                    statTile(
                        title: "Water",
                        value: waterDisplay(from: data),
                        systemImage: "drop.fill",
                        color: .blue
                    )
                    statTile(
                        title: "Sleep",
                        value: data.sleepHours.map { String(format: "%.1f h", $0) } ?? "—",
                        systemImage: "bed.double.fill",
                        color: .indigo
                    )
                }
                HStack(spacing: 12) {
                    statTile(
                        title: "Food",
                        value: data.energyKilocalories.map { "\(Int($0)) cal" } ?? "—",
                        systemImage: "fork.knife",
                        color: .orange
                    )
                    statTile(
                        title: "Caffeine",
                        value: data.caffeineMg.map { "\(Int($0)) mg" } ?? "—",
                        systemImage: "cup.and.saucer.fill",
                        color: .brown
                    )
                }
            } else {
                HStack {
                    Text("No health data yet for today.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Fetch") {
                        Task { await healthManager.refreshLatestForToday() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Insights", systemImage: "lightbulb.max.fill")
                    .font(.headline)
                Spacer()
                if insightManager.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await insightManager.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }

            if insightManager.insights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No insights yet")
                        .font(.subheadline).bold()
                    Text("Log migraines and connect Health & Weather to see trends and associations.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            } else {
                // Display top few, grouped lightly by priority
                let top = Array(insightManager.insights.prefix(8))
                LazyVStack(spacing: 10) {
                    ForEach(top) { insight in
                        insightCard(insight)
                    }
                }
            }

            if !insightManager.errors.isEmpty {
                ForEach(Array(insightManager.errors.enumerated()), id: \.offset) { _, err in
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        Text(err.localizedDescription).font(.footnote)
                        Spacer()
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var recentMigrainesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Recent Migraines", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await migraineManager.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            if migraineManager.migraines.isEmpty {
                Text("No migraines logged yet.")
                    .foregroundStyle(.secondary)
            } else {
                let recent = Array(migraineManager.migraines.prefix(5))
                VStack(spacing: 8) {
                    ForEach(recent, id: \.id) { m in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(colorForPain(m.painLevel))
                                .frame(width: 10, height: 10)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(dateRangeLabel(for: m))
                                        .font(.subheadline).bold()
                                    Spacer()
                                    Text("Pain \(m.painLevel)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                if !m.triggers.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(m.triggers, id: \.self) { t in
                                                Text(t.displayName)
                                                    .font(.caption)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.gray.opacity(0.15), in: Capsule())
                                            }
                                        }
                                    }
                                }
                                if let note = m.note, !note.isEmpty {
                                    Text(note)
                                        .font(.footnote)
                                        .lineLimit(2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Components

    private func statTile(title: String, value: String, systemImage: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.title3)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func insightCard(_ insight: Insight) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName(for: insight.category))
                .foregroundStyle(color(for: insight.priority))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline).bold()
                Text(insight.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text(insight.generatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                priorityBadge(insight.priority)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func priorityBadge(_ priority: Insight.Priority) -> some View {
        Text(priorityLabel(priority))
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color(for: priority).opacity(0.15), in: Capsule())
            .foregroundStyle(color(for: priority))
    }

    // MARK: - Actions

    private func resetIntakeInputs() {
        addWater = 0
        addCaffeine = 0
        addCalories = 0
        addSleepHours = 0
        intakeError = nil
    }

    private var allIntakeAddsAreZero: Bool {
        addWater == 0 && addCaffeine == 0 && addCalories == 0 && addSleepHours == 0
    }

    private func saveIntake() async {
        guard !isSavingIntake else { return }
        isSavingIntake = true
        intakeError = nil
        defer { isSavingIntake = false }

        do {
            // Persist each non-zero input to HealthKit
            if addWater > 0 {
                try await healthManager.saveWater(liters: addWater)
            }
            if addCaffeine > 0 {
                try await healthManager.saveCaffeine(mg: addCaffeine)
            }
            if addCalories > 0 {
                try await healthManager.saveEnergy(kcal: addCalories)
            }
            if addSleepHours > 0 {
                // Save a simple sleep interval ending now
                let end = Date()
                let start = end.addingTimeInterval(-addSleepHours * 3600.0)
                try await healthManager.saveSleep(from: start, to: end)
            }

            resetIntakeInputs()
            await healthManager.refreshLatestForToday()
        } catch {
            intakeError = error.localizedDescription
        }
    }

    private func initialLoadIfNeeded() async {
        // Kick off initial loads the first time the view appears
        async let a: () = insightManager.refresh()
        async let b: Void = weatherManager.refresh()
        async let c: Void = healthManager.refreshLatestForToday()
        _ = await (a, b, c)
    }

    private func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await insightManager.refresh() }
            group.addTask { await weatherManager.refresh() }
            group.addTask { await healthManager.refreshLatestForToday() }
        }
    }

    // MARK: - Helpers / Formatting

    private func waterDisplay(from data: HealthData) -> String {
        if useMetricUnits {
            if let liters = data.waterLiters {
                return String(format: "%.1f L", liters)
            } else { return "—" }
        } else {
            if let oz = data.waterOunces {
                return String(format: "%.0f oz", oz)
            } else { return "—" }
        }
    }

    private func color(for priority: Insight.Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    private func priorityLabel(_ priority: Insight.Priority) -> String {
        switch priority {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    private func iconName(for category: Insight.Category) -> String {
        switch category {
        case .trendFrequency: return "chart.line.uptrend.xyaxis"
        case .trendSeverity: return "waveform.path.ecg"
        case .trendDuration: return "clock"
        case .triggers: return "exclamationmark.octagon.fill"
        case .foods: return "fork.knife"
        case .intakeHydration: return "drop.fill"
        case .intakeSleep: return "bed.double.fill"
        case .intakeNutrition: return "fork.knife"
        case .sleepAssociation: return "zzz"
        case .weatherAssociation: return "cloud.sun"
        case .generative: return "sparkles"
        }
    }

    private func colorForPain(_ pain: Int) -> Color {
        switch pain {
        case 0...3: return .green
        case 4...6: return .orange
        default: return .red
        }
    }

    private func dateRangeLabel(for m: Migraine) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        let start = df.string(from: m.startDate)
        if let end = m.endDate {
            let endStr = df.string(from: end)
            return "\(start) – \(endStr)"
        } else {
            return "\(start) • Ongoing"
        }
    }

    private func conditionLabel(for condition: WeatherCondition) -> String {
        // WeatherKit's WeatherCondition is an enum; provide friendly labels
        switch condition {
        case .clear: return "Clear"
        case .mostlyClear: return "Mostly Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy: return "Cloudy"
        case .mostlyCloudy: return "Mostly Cloudy"
        case .drizzle: return "Drizzle"
        case .rain: return "Rain"
        case .heavyRain: return "Heavy Rain"
        case .strongStorms: return "Thunderstorms"
        case .snow: return "Snow"
        case .flurries: return "Flurries"
        case .sleet: return "Sleet"
        case .freezingRain: return "Freezing Rain"
        case .haze: return "Haze"
        case .foggy: return "Fog"
        case .windy: return "Windy"
        case .blowingSnow: return "Blowing Snow"
        case .frigid: return "Frigid"
        case .hot: return "Hot"
        case .blizzard: return "Blizzard"
        case .smoky: return "Smoky"
        default: return "Weather"
        }
    }

    private func symbolName(for condition: WeatherCondition) -> String {
        // Basic SF Symbols mapping for common conditions
        switch condition {
        case .clear, .mostlyClear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy, .mostlyCloudy: return "cloud.fill"
        case .drizzle, .rain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .strongStorms: return "cloud.bolt.rain.fill"
        case .snow, .flurries: return "cloud.snow.fill"
        case .sleet, .freezingRain: return "cloud.sleet.fill"
        case .haze, .foggy: return "cloud.fog.fill"
        case .windy: return "wind"
        case .blowingSnow, .blizzard: return "wind.snow"
        case .frigid: return "thermometer.snowflake"
        case .hot: return "thermometer.sun.fill"
        case .smoky: return "smoke.fill"
        default:
            // Fallback for any cases not explicitly handled or future additions
            return "cloud"
        }
    }

    private func symbolColor(for condition: WeatherCondition) -> Color {
        // Choose expressive but readable colors for each condition
        switch condition {
        case .clear, .mostlyClear:
            return .yellow
        case .partlyCloudy:
            return .orange
        case .cloudy, .mostlyCloudy:
            return .gray
        case .drizzle, .rain:
            return .blue
        case .heavyRain:
            return Color.blue.opacity(0.9)
        case .strongStorms:
            return .indigo
        case .snow, .flurries:
            return .cyan
        case .sleet, .freezingRain:
            return .teal
        case .haze, .foggy:
            return .gray.opacity(0.7)
        case .windy:
            return .teal
        case .blowingSnow, .blizzard:
            return .cyan
        case .frigid:
            return .blue
        case .hot:
            return .red
        case .smoky:
            return .brown
        default:
            return .gray
        }
    }
}
