//
//  MigraineEntryView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import SwiftUI
import SwiftData
import WeatherKit
import UIKit

struct MigraineEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthManager.self) private var healthManager
    @Environment(WeatherManager.self) private var weatherManager
    
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    var onMigraineSaved: (Migraine, UIWindowScene?) -> Void
    
    @Bindable private var viewModel: ViewModel = ViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Text(viewModel.greeting.isEmpty ? "We’ve got you." : viewModel.greeting)
                    .font(.title2).bold()

                Section("Data Retreival") {
                    // Health capsule
                    HStack(spacing: 10) {
                        if viewModel.isPullingHealth {
                            ProgressView()
                                .controlSize(.small)
                        } else if viewModel.healthError != nil {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        } else if viewModel.didPullHealth {
                            // Determine if we should warn (any of sleep/caffeine/water/calories explicitly 0)
                            let zeroHealthFlag: Bool = {
                                guard let h = healthManager.latestData else { return false }
                                let sleepZero = (h.sleepHours ?? -1) == 0
                                let caffeineZero = (h.caffeineMg ?? -1) == 0
                                let waterZero = (h.waterLiters ?? -1) == 0
                                let caloriesZero = (h.energyKilocalories ?? -1) == 0
                                return sleepZero || caffeineZero || waterZero || caloriesZero
                            }()
                            if zeroHealthFlag {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow.gradient)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green.gradient)
                            }
                        }

                        Text(viewModel.isPullingHealth
                             ? "Pulling from Apple Health"
                             : (viewModel.healthError == nil ? "Pulled from Apple Health" : "Failed to pull from Apple Health"))
                        .foregroundStyle(viewModel.healthError == nil ? .primary : .secondary)
                        .font(.subheadline)
                        .bold(viewModel.healthError != nil)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.thinMaterial)
                    )

                    if let h = healthManager.latestData, viewModel.healthError == nil {
                        VStack {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if let w = h.waterLiters {
                                        Label {
                                            Text(viewModel.displayWater(w, useMetricUnits: useMetricUnits))
                                        } icon: {
                                            Image(systemName: "drop.fill")
                                                .foregroundStyle(w == 0 ? .red : .secondary)
                                        }
                                    }
                                    if let s = h.sleepHours {
                                        Label {
                                            Text("\(String(format: "%.1f", s)) h sleep")
                                        } icon: {
                                            Image(systemName: "bed.double.fill")
                                                .foregroundStyle(s == 0 ? .red : .secondary)
                                        }
                                    }
                                    if let rhr = h.restingHeartRate {
                                        Label("\(rhr) bpm RHR", systemImage: "heart.fill")
                                    }
                                    
                                    if let phase = h.menstrualPhase {
                                        Label {
                                            Text(viewModel.displayMenstrualPhase(phase))
                                        } icon: {
                                            Image(systemName: viewModel.menstrualPhaseIcon(phase))
                                                .foregroundStyle(viewModel.menstrualPhaseColor(phase).gradient)
                                        }
                                    }
                                    
                                    // add blood oxygen, if applicable
                                    if let spo2 = h.bloodOxygenPercent {
                                        let percent = spo2 * 100.0
                                        Label {
                                            if percent.truncatingRemainder(dividingBy: 1) == 0 {
                                                Text("\(Int(percent))% SpO₂")
                                            } else {
                                                Text(String(format: "%.1f%% SpO₂", percent))
                                            }
                                        } icon: {
                                            Image(systemName: "lungs.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if let kcal = h.energyKilocalories {
                                        Label {
                                            if useMetricUnits {
                                                let kJ = (kcal * 4.184).rounded()
                                                Text("\(Int(kJ)) kJ")
                                            } else {
                                                Text("\(Int(kcal)) kcal")
                                            }
                                        } icon: {
                                            Image(systemName: "fork.knife")
                                                .foregroundStyle(kcal == 0 ? .red : .secondary)
                                        }
                                    }
                                    if let caf = h.caffeineMg {
                                        Label {
                                            Text("\(Int(caf)) mg caffeine")
                                        } icon: {
                                            Image(systemName: "cup.and.saucer.fill")
                                                .foregroundStyle(caf == 0 ? .red : .secondary)
                                        }
                                    }
                                    if let steps = h.stepCount {
                                        Label("\(steps) steps", systemImage: "figure.walk")
                                    }
                                    
                                    if let glucose = h.glucoseMgPerdL {
                                        Label {
                                            Text(viewModel.displayGlucose(mgPerdL: glucose, useMetricUnits: useMetricUnits))
                                        } icon: {
                                            Image(systemName: "syringe")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            
                            // Edit button + expandable editor (centered)
                            if (!viewModel.isEditingHealthValues) {
                                HStack {
                                    Spacer()
                                    Button(viewModel.isEditingHealthValues ? "Cancel Editing" : "Edit Intake Values") {
                                        Haptics.lightImpact()
                                        toggleHealthEditor()
                                    }
                                    .tint(.blue)
                                    Spacer()
                                }
                                .padding([.top, .horizontal])
                            }
                            
                            if viewModel.isEditingHealthValues {
                                IntakeEditorView(
                                    addWater: $viewModel.addWater,
                                    addCaffeine: $viewModel.addCaffeine,
                                    addFood: $viewModel.addFood,
                                    addSleepHours: $viewModel.addSleepHours,
                                    useMetricUnits: useMetricUnits,
                                    waterRange: viewModel.waterRange(useMetricUnits: useMetricUnits),
                                    waterStep: viewModel.waterStep(useMetricUnits: useMetricUnits),
                                    waterDisplay: { viewModel.waterDisplay($0, useMetricUnits: useMetricUnits) },
                                    isSaving: viewModel.isSavingHealthEdits,
                                    errorMessage: viewModel.healthEditErrorMessage,
                                    allAddsAreZero: viewModel.allAddsAreZero,
                                    onAdd: {
                                        // The actual save and success haptic will be in saveHealthEdits()
                                        Task { await saveHealthEdits() }
                                    },
                                    onCancel: {
                                        Haptics.lightImpact()
                                        withAnimation { viewModel.isEditingHealthValues = false }
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                            }
                        }
                    }

                    // Weather capsule
                    VStack {
                        HStack(spacing: 10) {
                            if viewModel.isPullingWeather {
                                ProgressView()
                                    .controlSize(.small)
                            } else if viewModel.didPullWeather {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if viewModel.weatherError != nil {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            
                            VStack {
                                Text(
                                    viewModel.isPullingWeather
                                        ? "Pulling local weather"
                                        : (viewModel.didPullWeather
                                            ? (viewModel.weatherError == nil ? "Pulled local weather" : "Using recent weather")
                                            : "Failed to pull weather")
                                )
                                .foregroundStyle(viewModel.didPullWeather ? .primary : .secondary)
                                .font(.subheadline)
                                .bold(!viewModel.didPullWeather && viewModel.weatherError != nil)
                                
                                Spacer(minLength: 0)
                            }
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 6) {
                            Text(" Weather")
                            Text("•")
                                .accessibilityHidden(true)
                            Link("Legal", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                            
                            Spacer()
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, 2)
                        .padding(.leading, 5)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.thinMaterial)
                    )

                    if viewModel.didPullWeather {
                        // Single row with two columns, both leading aligned
                        
                        
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let loc = weatherManager.locationString, !loc.isEmpty {
                                    Label(loc, systemImage: "mappin.and.ellipse")
                                }
                                
                                if let t = weatherManager.temperature {
                                    Label(viewModel.displayTemperature(t, useMetricUnits: useMetricUnits), systemImage: "thermometer.medium")
                                }
                                if let h = weatherManager.humidityPercentString {
                                    Label(h, systemImage: "humidity.fill")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: 4) {
                                if let p = weatherManager.pressure {
                                    Label(viewModel.displayPressure(p, useMetricUnits: useMetricUnits), systemImage: "gauge.with.dots.needle.bottom.50percent")
                                }
                                if let c = weatherManager.condition {
                                    Label(c.description.capitalized, systemImage: "cloud.sun")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Duration") {
                    DatePicker(
                        "Started",
                        selection: $viewModel.startDate,
                        in: (Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())...,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Toggle("Ongoing", isOn: $viewModel.isOngoing)
                        .onChange(of: $viewModel.isOngoing.wrappedValue) { _, new in
                            Haptics.lightImpact()
                            viewModel.setOngoing(new)
                        }

                    if !viewModel.isOngoing {
                        DatePicker("End", selection: $viewModel.endDate, in: $viewModel.startDate.wrappedValue..., displayedComponents: [.date, .hourAndMinute])
                    } else {
                        Text("We'll start a neat little Live Activity to help you track duration!")
                            .foregroundStyle(.gray)
                    }
                }

                Section("Experience") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Pain Level")
                            Spacer()
                            Text("\(viewModel.painLevel)")
                                .bold()
                                .foregroundStyle(Severity.from(painLevel: $viewModel.painLevel.wrappedValue).color)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.painLevel) },
                                set: { viewModel.painLevel = Int(round($0)) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .tint(viewModel.gradientColor(for: viewModel.painLevel))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stress Level")
                            Spacer()
                            Text("\(viewModel.stressLevel)")
                                .bold()
                                .foregroundStyle(.indigo)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.stressLevel) },
                                set: { viewModel.stressLevel = Int(round($0)) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .tint(.indigo)
                    }
                    Toggle("Pin this migraine", isOn: $viewModel.pinned)
                        .onChange(of: $viewModel.pinned.wrappedValue) { _, _ in Haptics.lightImpact() }
                }

                Section("Possible Triggers") {
                    // Search field with inline clear button
                    HStack {
                        TextField("Search triggers", text: $viewModel.triggerSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !viewModel.triggerSearchText.isEmpty {
                            Button {
                                Haptics.lightImpact()
                                viewModel.triggerSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
                        }
                    }

                    // Grouped, filtered multi-select list
                    ForEach(MigraineTrigger.Group.allCases, id: \.self) { group in
                        let items = viewModel.filteredTriggers(for: group, search: $viewModel.triggerSearchText.wrappedValue)
                        if !items.isEmpty {
                            DisclosureGroup(group.displayName) {
                                ForEach(items, id: \.self) { trig in
                                    Button {
                                        Haptics.lightImpact()
                                        viewModel.toggleTrigger(trig)
                                    } label: {
                                        HStack {
                                            Text(trig.displayName)
                                            Spacer()
                                            if viewModel.selectedTriggers.contains(trig) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.red)
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Custom trigger input
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Add custom trigger", text: $viewModel.customTriggerInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onSubmit { viewModel.addCustomTrigger() }
                            Button {
                                Haptics.lightImpact()
                                viewModel.addCustomTrigger()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(viewModel.customTriggerInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if !viewModel.customTriggers.isEmpty {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 120), spacing: 6)],
                                alignment: .leading,
                                spacing: 6
                            ) {
                                ForEach(Array(viewModel.customTriggers.enumerated()), id: \.offset) { idx, label in
                                    HStack(spacing: 6) {
                                        Text(label)
                                            .font(.caption)
                                            .padding(.vertical, 4)
                                            .padding(.leading, 10)
                                        Button {
                                            Haptics.lightImpact()
                                            viewModel.removeCustomTrigger(at: idx)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.trailing, 6)
                                    }
                                    .background(
                                        Capsule().fill(Color.secondary.opacity(0.15))
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if viewModel.selectedTriggers.isEmpty && viewModel.customTriggers.isEmpty {
                        Text("No triggers selected").foregroundStyle(.secondary)
                    } else {
                        let total = viewModel.selectedTriggers.count + viewModel.customTriggers.count
                        Text("\(total) selected")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Food Sensitivities") {
                    TextEditor(text: $viewModel.foodsText)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if $viewModel.foodsText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("List foods eaten around this time (comma or newline separated)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }

                Section("Notes") {
                    TextEditor(text: $viewModel.noteText)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if $viewModel.noteText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Add any details you want to remember")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }
            }
            .navigationTitle("New Migraine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.lightImpact()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Haptics.lightImpact()
                        Task { await submitTappedAsync() }
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .task {
            viewModel.resetGreeting()
            if viewModel.endDate < viewModel.startDate { viewModel.endDate = viewModel.startDate }
            await startHealthFetch()
            await startWeatherFetch()
        }
        .alert("Cannot Save", isPresented: $viewModel.showValidationAlert, actions: {
            Button("OK", role: .cancel) {
                Haptics.error()
            }
        }, message: {
            Text(viewModel.validationMessage)
        })
        .alert("Weather Not Attached", isPresented: $viewModel.showWeatherBackdateAlert, actions: {
            Button("OK", role: .cancel) {
                Haptics.lightImpact()
            }
        }, message: {
            Text(viewModel.weatherBackdateMessage)
        })
        .presentationDetents([.large])
        // Snap water to new step/range whenever unit preference changes
        .onChange(of: useMetricUnits) { _, _ in
            // Use the stored viewModel here to avoid dynamicMember binding confusion
            viewModel.addWater = viewModel.snap(viewModel.addWater, toStep: viewModel.waterStep(useMetricUnits: useMetricUnits), in: viewModel.waterRange(useMetricUnits: useMetricUnits))
        }
        .onChange(of: viewModel.startDate) { _, _ in
            Task { await startHealthFetch(); await startWeatherFetch() }
        }
        .onChange(of: viewModel.isOngoing) { _, _ in
            Task { await startHealthFetch(); await startWeatherFetch() }
        }
        .onChange(of: viewModel.endDate) { _, _ in
            if !viewModel.isOngoing {
                Task { await startHealthFetch(); await startWeatherFetch() }
            }
        }
    }


    // MARK: - Health editor actions

    private func toggleHealthEditor() {
        if !viewModel.isEditingHealthValues {
            viewModel.addWater = 0
            viewModel.addFood = 0
            viewModel.addCaffeine = 0
            viewModel.addSleepHours = 0
            viewModel.healthEditErrorMessage = nil
        }
        withAnimation { viewModel.isEditingHealthValues.toggle() }
    }

    private func saveHealthEdits() async {
        guard let current = healthManager.latestData else { return }
        viewModel.isSavingHealthEdits = true
        defer { viewModel.isSavingHealthEdits = false }

        do {
            // Water
            if viewModel.addWater > 0 {
                let liters = useMetricUnits ? viewModel.addWater : (viewModel.addWater / 33.814)
                try await healthManager.saveWater(liters: liters)
                current.waterLiters = (current.waterLiters ?? 0) + liters
            }
            // Calories
            if viewModel.addFood > 0 {
                try await healthManager.saveEnergy(kcal: viewModel.addFood)
                current.energyKilocalories = (current.energyKilocalories ?? 0) + viewModel.addFood
            }
            // Caffeine
            if viewModel.addCaffeine > 0 {
                try await healthManager.saveCaffeine(mg: viewModel.addCaffeine)
                current.caffeineMg = (current.caffeineMg ?? 0) + viewModel.addCaffeine
            }
            // Sleep
            if viewModel.addSleepHours > 0 {
                let end = Date()
                let start = end.addingTimeInterval(-viewModel.addSleepHours * 3600.0)
                try await healthManager.saveSleep(from: start, to: end)
                current.sleepHours = (current.sleepHours ?? 0) + viewModel.addSleepHours
            }

            // Refresh snapshot to reconcile with HealthKit aggregates
            await healthManager.refreshLatestForToday()

            viewModel.healthEditErrorMessage = nil
            withAnimation { viewModel.isEditingHealthValues = false }
            Haptics.success()
        } catch {
            viewModel.healthEditErrorMessage = "Failed to save to Apple Health: \(error.localizedDescription)"
            Haptics.error()
        }
    }

    // MARK: - Fetch orchestration

    private func startHealthFetch() async {
        viewModel.isPullingHealth = true
        viewModel.didPullHealth = false
        viewModel.healthError = nil

        // Use the selected start/end to fetch a migraine-window snapshot
        await healthManager.refreshLatestForToday()

        // Reflect results
        if let error = healthManager.lastError {
            viewModel.healthError = error
            viewModel.didPullHealth = false
        } else {
            viewModel.didPullHealth = (healthManager.latestData != nil)
        }
        viewModel.isPullingHealth = false
    }

    private func startWeatherFetch() async {
        viewModel.isPullingWeather = true
        viewModel.didPullWeather = false
        viewModel.weatherError = nil

        // If the selected start date is not today, skip weather and alert the user.
        let cal = Calendar.current
        if !cal.isDateInToday(viewModel.startDate) {
            viewModel.isPullingWeather = false
            viewModel.didPullWeather = false
            viewModel.weatherError = nil
            viewModel.showWeatherBackdateAlert = true
            viewModel.weatherBackdateMessage = "Weather isn't attached for past dates. We only attach current conditions for migraines started today."
            return
        }

        await weatherManager.refresh()

        // Consider it "pulled" if we have at least one of the core readings, even if refresh errored.
        let hasAny = weatherManager.temperature != nil ||
                     weatherManager.pressure != nil ||
                     weatherManager.humidity != nil ||
                     weatherManager.condition != nil

        if let error = weatherManager.error {
            viewModel.weatherError = error
            viewModel.didPullWeather = hasAny
        } else {
            viewModel.didPullWeather = hasAny
        }
        viewModel.isPullingWeather = false
    }

    private func buildWeatherData(forDate date: Date) -> WeatherData? {
        let pressureHpa: Double? = {
            guard let p = weatherManager.pressure else { return nil }
            let hPa = p.converted(to: .hectopascals).value
            return hPa
        }()
        let tempC: Double? = weatherManager.temperature?.converted(to: .celsius).value
        let humidityPercent: Double? = weatherManager.humidity.map { $0 * 100.0 }
        let condition: WeatherCondition? = weatherManager.condition
        let location: String? = weatherManager.locationString

        if let ph = pressureHpa, let tc = tempC, let hp = humidityPercent, let cond = condition {
            return WeatherData(
                barometricPressureHpa: ph,
                temperatureCelsius: tc,
                humidityPercent: hp,
                condition: cond,
                createdAt: date,
                locationDescription: location
            )
        } else if tempC != nil || pressureHpa != nil || humidityPercent != nil || condition != nil {
            return WeatherData(
                barometricPressureHpa: pressureHpa ?? 0,
                temperatureCelsius: tempC ?? 0,
                humidityPercent: humidityPercent ?? 0,
                condition: condition ?? .clear,
                createdAt: date,
                locationDescription: location
            )
        } else {
            return nil
        }
    }

    // MARK: - Save
    private func submitTappedAsync() async {
        // Basic validations
        let earliest = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        if viewModel.startDate < earliest {
            await MainActor.run {
                viewModel.validationMessage = "Start time cannot be more than 1 day in the past."
                viewModel.showValidationAlert = true
            }
            Haptics.error()
            return
        }

        guard viewModel.validateBeforeSave() else {
            Haptics.error()
            return
        }

        // Attempt to fetch a Health snapshot for the migraine window
        var healthModel: HealthData? = nil
        do {
            try? await Task.sleep(nanoseconds: 200_000_000)
            let snapshot = try await healthManager.fetchSnapshotForMigraine(start: Date(), end: nil)
            healthModel = snapshot
        } catch {
            // If this fails (e.g., not authorized), proceed without health
            print("Failed to fetch Health snapshot for migraine window: \(error)")
        }

        // Ensure we have a recent weather reading; then build a WeatherData using the migraine's start date
        let cal = Calendar.current
        let weatherModel: WeatherData?
        if cal.isDateInToday(viewModel.startDate) {
            await weatherManager.refresh()
            weatherModel = buildWeatherData(forDate: viewModel.startDate)
        } else {
            weatherModel = nil
            // Ensure the user sees why weather won't be attached
            viewModel.showWeatherBackdateAlert = true
            if viewModel.weatherBackdateMessage.isEmpty {
                viewModel.weatherBackdateMessage = "Weather isn't attached for past dates. We only attach current conditions for migraines started today."
            }
        }

        // Foods parsing
        let foods: [String] = viewModel.parseFoods()

        let newMigraine = Migraine(
            pinned: viewModel.pinned,
            startDate: viewModel.startDate,
            endDate: viewModel.isOngoing ? nil : viewModel.endDate,
            painLevel: viewModel.painLevel,
            stressLevel: viewModel.stressLevel,
            note: viewModel.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : viewModel.noteText,
            insight: nil,
            triggers: Array(viewModel.selectedTriggers),
            customTriggers: viewModel.customTriggers,
            foodsEaten: foods,
            weather: weatherModel,
            health: healthModel
        )

        Haptics.success()
        onMigraineSaved(newMigraine, nil)
    }
}

#Preview("Entry View – Empty State") {
    let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: User.self, Migraine.self, WeatherData.self, HealthData.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Preview ModelContainer setup failed: \(error)")
        }
    }()

    // Lightweight preview managers
    let previewHealthManager = HealthManager()
    let previewWeatherManager = WeatherManager()

    return MigraineEntryView(onMigraineSaved: { migraine, _ in
        print("Saved migraine in preview: start=\(migraine.startDate), pain=\(migraine.painLevel)")
    })
    .modelContainer(container)
    .environment(previewWeatherManager)
    .environment(previewHealthManager)
    .environment(\.locale, .init(identifier: "en_US"))
}

