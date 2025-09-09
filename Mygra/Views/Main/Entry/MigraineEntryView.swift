//
//  MigraineEntryView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/29/25.
//

import SwiftUI
import SwiftData
import WeatherKit

struct MigraineEntryView: View {
    @Environment(HealthManager.self) private var healthManager
    @Environment(WeatherManager.self) private var weatherManager
    @Environment(MigraineManager.self) private var migraineManager

    var onMigraineSaved: (Migraine) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ViewModel = ViewModel()
    @AppStorage("useMetricUnits") private var useMetricUnits: Bool = false

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            Form {
                Text(vm.greeting.isEmpty ? "We’ve got you." : vm.greeting)
                    .font(.title2).bold()

                Section("Data Retreival") {
                    // Health capsule
                    HStack(spacing: 10) {
                        if vm.isPullingHealth {
                            ProgressView()
                                .controlSize(.small)
                        } else if vm.healthError != nil {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        } else if vm.didPullHealth {
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
                                    .foregroundStyle(.yellow)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }

                        Text(vm.isPullingHealth
                             ? "Pulling from Apple Health"
                             : (vm.healthError == nil ? "Pulled from Apple Health" : "Failed to pull from Apple Health"))
                        .foregroundStyle(vm.healthError == nil ? .primary : .secondary)
                        .font(.subheadline)
                        .bold(vm.healthError != nil)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.thinMaterial)
                    )

                    if let h = healthManager.latestData, vm.healthError == nil {
                        VStack {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if let w = h.waterLiters {
                                        Label {
                                            Text(displayWater(w))
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
                                            Text(displayMenstrualPhase(phase))
                                        } icon: {
                                            Image(systemName: menstrualPhaseIcon(phase))
                                                .foregroundStyle(menstrualPhaseColor(phase))
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
                                            Text("\(Int(kcal)) cal")
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
                                            Text(displayGlucose(glucoseMgPerdL: glucose))
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
                            if (!vm.isEditingHealthValues) {
                                HStack {
                                    Spacer()
                                    Button(vm.isEditingHealthValues ? "Cancel Editing" : "Edit Intake Values") {
                                        lightImpact()
                                        toggleHealthEditor()
                                    }
                                    .tint(.blue)
                                    Spacer()
                                }
                                .padding()
                            }
                            
                            if vm.isEditingHealthValues {
                                IntakeEditorView(
                                    // Bindings for values
                                    addWater: $vm.addWater,
                                    addCaffeine: $vm.addCaffeine,
                                    addCalories: $vm.addCalories,
                                    addSleepHours: $vm.addSleepHours,
                                    // Display/config
                                    useMetricUnits: useMetricUnits,
                                    waterRange: waterRange,
                                    waterStep: waterStep,
                                    waterDisplay: waterDisplay(_:),
                                    // Status/flags
                                    isSaving: vm.isSavingHealthEdits,
                                    errorMessage: vm.healthEditErrorMessage,
                                    allAddsAreZero: vm.allAddsAreZero,
                                    // Actions
                                    onAdd: {
                                        // The actual save and success haptic will be in saveHealthEdits()
                                        Task { await saveHealthEdits() }
                                    },
                                    onCancel: {
                                        lightImpact()
                                        withAnimation { vm.isEditingHealthValues = false }
                                    }
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }

                    // Weather capsule
                    HStack(spacing: 10) {
                        if vm.isPullingWeather {
                            ProgressView()
                                .controlSize(.small)
                        } else if vm.weatherError != nil {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        } else if vm.didPullWeather {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        Text(vm.isPullingWeather
                             ? "Pulling local weather"
                             : (vm.weatherError == nil ? "Pulled local weather" : "Failed to pull weather"))
                        .foregroundStyle(vm.weatherError == nil ? .primary : .secondary)
                        .font(.subheadline)
                        .bold(vm.weatherError != nil)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.thinMaterial)
                    )

                    if vm.didPullWeather, vm.weatherError == nil {
                        // Single row with two columns, both leading aligned
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                if let t = weatherManager.temperature {
                                    Label(displayTemperature(t), systemImage: "thermometer.medium")
                                }
                                if let h = weatherManager.humidityPercentString {
                                    Label(h, systemImage: "humidity.fill")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: 4) {
                                if let p = weatherManager.pressure {
                                    Label(displayPressure(p), systemImage: "gauge.with.dots.needle.bottom.50percent")
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
                    DatePicker("Started", selection: $vm.startDate, displayedComponents: [.date, .hourAndMinute])

                    Toggle("Ongoing", isOn: $vm.isOngoing)
                        .onChange(of: $vm.isOngoing.wrappedValue) { _, new in
                            lightImpact()
                            vm.setOngoing(new)
                        }

                    if !vm.isOngoing {
                        DatePicker("End", selection: $vm.endDate, in: $vm.startDate.wrappedValue..., displayedComponents: [.date, .hourAndMinute])
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
                            Text("\(vm.painLevel)")
                                .bold()
                                .foregroundStyle(Severity.from(painLevel: $vm.painLevel.wrappedValue).color)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(vm.painLevel) },
                                set: { vm.painLevel = Int(round($0)) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .tint(gradientColor(for: vm.painLevel))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stress Level")
                            Spacer()
                            Text("\(vm.stressLevel)")
                                .bold()
                                .foregroundStyle(.indigo)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(vm.stressLevel) },
                                set: { vm.stressLevel = Int(round($0)) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .tint(.indigo)
                    }
                }

                Section("Possible Triggers") {
                    // Search field with inline clear button
                    HStack {
                        TextField("Search triggers", text: $vm.triggerSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !vm.triggerSearchText.isEmpty {
                            Button {
                                lightImpact()
                                vm.triggerSearchText = ""
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
                        let items = filteredTriggers(for: group, search: $vm.triggerSearchText.wrappedValue)
                        if !items.isEmpty {
                            DisclosureGroup(group.rawValue.capitalized) {
                                ForEach(items, id: \.self) { trig in
                                    Button {
                                        lightImpact()
                                        vm.toggleTrigger(trig)
                                    } label: {
                                        HStack {
                                            Text(trig.displayName)
                                            Spacer()
                                            if vm.selectedTriggers.contains(trig) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.blue)
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if vm.selectedTriggers.isEmpty {
                        Text("No triggers selected").foregroundStyle(.secondary)
                    } else {
                        Text("\(vm.selectedTriggers.count) selected")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Food Sensitivities") {
                    TextEditor(text: $vm.foodsText)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if $vm.foodsText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("List foods eaten around this time (comma or newline separated)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }
                
                Section("Options") {
                    Toggle("Pin this migraine", isOn: $vm.pinned)
                        .onChange(of: $vm.pinned.wrappedValue) { _, _ in lightImpact() }
                }

                Section("Notes") {
                    TextEditor(text: $vm.noteText)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if $vm.noteText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                        lightImpact()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        // Validation happens inside finishTapped(); we’ll do success haptic there on success.
                        lightImpact()
                        finishTapped()
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .task {
            vm.resetGreeting()
            await startHealthFetch()
            await startWeatherFetch()
            if vm.endDate < vm.startDate { vm.endDate = vm.startDate }
        }
        .alert("Cannot Save", isPresented: $vm.showValidationAlert, actions: {
            Button("OK", role: .cancel) {
                errorHaptic()
            }
        }, message: {
            Text(vm.validationMessage)
        })
        .presentationDetents([.medium, .large])
        // Snap water to new step/range whenever unit preference changes
        .onChange(of: useMetricUnits) { _, _ in
            // Use the stored viewModel here to avoid dynamicMember binding confusion
            viewModel.addWater = snap(viewModel.addWater, toStep: waterStep, in: waterRange)
        }
    }

    // MARK: - Haptics

    private func lightImpact() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
    }

    private func mediumImpact() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred()
    }

    private func successHaptic() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    private func errorHaptic() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.error)
    }

    // MARK: - Helpers (unit-aware display)

    private func displayWater(_ liters: Double) -> String {
        if useMetricUnits {
            return String(format: "%.1f L water", liters)
        } else {
            let ounces = liters * 33.814
            return String(format: "%.0f fl oz water", ounces.rounded())
        }
    }
    
    private func displayGlucose(glucoseMgPerdL: Double) -> String {
        if useMetricUnits {
            let mmol = glucoseMgPerdL / 18.0
            return String(format: "%.1f mmol/L glucose", mmol)
        } else {
            return String(format: "%.0f mg/dL glucose", glucoseMgPerdL.rounded())
        }
    }
    
    private func displayMenstrualPhase(_ phase: MenstrualPhase) -> String {
        switch phase {
        case .menstrual: return "Menstrual phase"
        case .follicular: return "Follicular phase"
        case .ovulatory: return "Ovulatory phase"
        case .luteal: return "Luteal phase"
        }
    }
    
    private func menstrualPhaseIcon(_ phase: MenstrualPhase) -> String {
        switch phase {
        case .menstrual: return "drop.circle.fill"
        case .follicular: return "leaf.fill"
        case .ovulatory: return "sparkles"
        case .luteal: return "circle.lefthalf.filled"
        }
    }
    
    private func menstrualPhaseColor(_ phase: MenstrualPhase) -> Color {
        switch phase {
        case .menstrual: return .pink
        case .follicular: return .green
        case .ovulatory: return .yellow
        case .luteal: return .orange
        }
    }

    private func displayTemperature(_ temp: Measurement<UnitTemperature>) -> String {
        let value: Double
        let unit: String
        if useMetricUnits {
            value = temp.converted(to: .celsius).value
            unit = "°C"
        } else {
            value = temp.converted(to: .fahrenheit).value
            unit = "°F"
        }
        return "\(Int(round(value))) \(unit)"
    }

    private func displayPressure(_ pressure: Measurement<UnitPressure>) -> String {
        if useMetricUnits {
            let hpa = pressure.converted(to: .hectopascals).value
            return String(format: "%.0f hPa", hpa)
        } else {
            let inHg = pressure.converted(to: .inchesOfMercury).value
            return String(format: "%.2f inHg", inHg)
        }
    }

    // MARK: - Slider helpers

    private var waterRange: ClosedRange<Double> {
        if useMetricUnits { 0.0...5.0 } else { 0.0...170.0 } // liters vs fl oz
    }
    private var waterStep: Double {
        useMetricUnits ? 0.1 : 1.0
    }
    private func waterDisplay(_ value: Double) -> String {
        if useMetricUnits {
            return String(format: "+%.1f L", value)
        } else {
            return String(format: "+%.0f fl oz", value)
        }
    }
    private func snap(_ value: Double, toStep step: Double, in range: ClosedRange<Double>) -> Double {
        guard step > 0 else { return min(max(value, range.lowerBound), range.upperBound) }
        let snapped = (value / step).rounded() * step
        return min(max(snapped, range.lowerBound), range.upperBound)
    }

    // MARK: - Experience color mapping (0→green, 5→yellow, 10→red)

    private func gradientColor(for value: Int) -> Color {
        let v = max(0, min(10, value))
        if v <= 5 {
            // green (0,1,0) to yellow (1,1,0)
            let t = Double(v) / 5.0
            return Color(red: t, green: 1.0, blue: 0.0)
        } else {
            // yellow (1,1,0) to red (1,0,0)
            let t = Double(v - 5) / 5.0
            return Color(red: 1.0, green: 1.0 - t, blue: 0.0)
        }
    }

    // MARK: - Health editor actions

    private func toggleHealthEditor() {
        if !viewModel.isEditingHealthValues {
            viewModel.addWater = 0
            viewModel.addCalories = 0
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
            if viewModel.addCalories > 0 {
                try await healthManager.saveEnergy(kcal: viewModel.addCalories)
                current.energyKilocalories = (current.energyKilocalories ?? 0) + viewModel.addCalories
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
            successHaptic()
        } catch {
            viewModel.healthEditErrorMessage = "Failed to save to Apple Health: \(error.localizedDescription)"
            errorHaptic()
        }
    }

    // MARK: - Fetch orchestration

    private func startHealthFetch() async {
        viewModel.isPullingHealth = true
        viewModel.didPullHealth = false
        viewModel.healthError = nil

        // Kick off authorization + snapshot for today
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

        await weatherManager.refresh()

        // Reflect results
        if let error = weatherManager.error {
            viewModel.weatherError = error
            viewModel.didPullWeather = false
        } else {
            // Consider it "pulled" if we got at least one of the core readings
            let hasAny = weatherManager.temperature != nil ||
                         weatherManager.pressure != nil ||
                         weatherManager.humidity != nil ||
                         weatherManager.condition != nil
            viewModel.didPullWeather = hasAny
        }
        viewModel.isPullingWeather = false
    }

    // MARK: - Triggers helpers

    private func filteredTriggers(for group: MigraineTrigger.Group, search: String) -> [MigraineTrigger] {
        let all = MigraineTrigger.cases(for: group)
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let lower = trimmed.lowercased()
        return all.filter { $0.displayName.lowercased().contains(lower) }
    }

    // MARK: - Save

    private func finishTapped() {
        // Basic validations
        guard viewModel.validateBeforeSave() else {
            errorHaptic()
            return
        }

        // Build WeatherData from current WeatherManager readings if available
        let weatherModel: WeatherData? = {
            guard viewModel.didPullWeather, viewModel.weatherError == nil else { return nil }
            let pressureHpa: Double? = {
                guard let p = weatherManager.pressure else { return nil }
                let hPa = p.converted(to: .hectopascals).value
                return hPa
            }()
            let tempC: Double? = weatherManager.temperature?.converted(to: .celsius).value
            let humidityPercent: Double? = weatherManager.humidity.map { $0 * 100.0 }
            let condition: WeatherCondition? = weatherManager.condition

            if let ph = pressureHpa, let tc = tempC, let hp = humidityPercent, let cond = condition {
                return WeatherData(
                    barometricPressureHpa: ph,
                    temperatureCelsius: tc,
                    humidityPercent: hp,
                    condition: cond
                )
            } else if tempC != nil || pressureHpa != nil || humidityPercent != nil || condition != nil {
                return WeatherData(
                    barometricPressureHpa: pressureHpa ?? 0,
                    temperatureCelsius: tempC ?? 0,
                    humidityPercent: humidityPercent ?? 0,
                    condition: condition ?? .clear
                )
            } else {
                return nil
            }
        }()

        // Health: reuse the snapshot object if available (already a SwiftData model)
        let healthModel: HealthData? = viewModel.didPullHealth && viewModel.healthError == nil ? healthManager.latestData : nil

        // Foods parsing
        let foods: [String] = viewModel.parseFoods()

        // Create the migraine
        let newMigraine = migraineManager.create(
            startDate: viewModel.startDate,
            endDate: viewModel.isOngoing ? nil : viewModel.endDate,
            painLevel: viewModel.painLevel,
            stressLevel: viewModel.stressLevel,
            pinned: viewModel.pinned,
            note: viewModel.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : viewModel.noteText,
            insight: nil,
            triggers: Array(viewModel.selectedTriggers),
            foodsEaten: foods,
            weather: weatherModel,
            health: healthModel
        )

        // Start Live Activity if ongoing
        if newMigraine.isOngoing {
            MigraineActivityCenter.start(for: newMigraine.id, startDate: newMigraine.startDate, severity: newMigraine.painLevel, notes: newMigraine.note ?? "")
        }

        successHaptic()
        // Done
        onMigraineSaved(newMigraine)
    }
}

