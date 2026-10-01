//
//  IntakeEditorView.swift
//  MygraFeatureShared
//
//  The four intake sliders (water, caffeine, food, sleep) bound to one
//  `IntakeAdditions` value. Shared by the dashboard Quick Add, the entry form, and the
//  modify sheet.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

public struct IntakeEditorView: View {
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    @Binding var additions: IntakeAdditions
    let isSaving: Bool
    let errorMessage: String?
    let onAdd: () -> Void
    let onCancel: () -> Void

    // Debounce flags so continuous drags don't spam haptics.
    @State private var waterGate = false
    @State private var caffeineGate = false
    @State private var foodGate = false
    @State private var sleepGate = false

    public init(
        additions: Binding<IntakeAdditions>,
        isSaving: Bool,
        errorMessage: String?,
        onAdd: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        _additions = additions
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onAdd = onAdd
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 12) {
                sliderRow(
                    systemImage: "drop.fill",
                    tint: .blue,
                    value: $additions.waterLiters,
                    range: IntakeAdditions.waterRangeLiters,
                    step: IntakeAdditions.waterStep(useMetricUnits: useMetricUnits),
                    display: waterDisplay(additions.waterLiters),
                    accessibility: useMetricUnits
                        ? "Add \(Int(additions.waterLiters * 1000)) milliliters of water"
                        : "Add \(Int((additions.waterLiters * UnitConversion.litersToFluidOunces).rounded())) fluid ounces of water",
                    gate: $waterGate
                )
                sliderRow(
                    systemImage: "cup.and.saucer.fill",
                    tint: .brown,
                    value: $additions.caffeineMg,
                    range: IntakeAdditions.caffeineRangeMg,
                    step: IntakeAdditions.caffeineStepMg,
                    display: "+\(Int(additions.caffeineMg)) mg",
                    accessibility: "Add \(Int(additions.caffeineMg)) milligrams of caffeine",
                    gate: $caffeineGate
                )
                foodRow
                sliderRow(
                    systemImage: "bed.double.fill",
                    tint: .indigo,
                    value: $additions.sleepHours,
                    range: IntakeAdditions.sleepRangeHours,
                    step: IntakeAdditions.sleepStepHours,
                    display: "+" + sleepDisplay,
                    accessibility: "Add " + sleepDisplay + " of sleep",
                    gate: $sleepGate
                )
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    Haptics.lightImpact()
                    onCancel()
                }
                .glassActionButton(tint: .gray, prominent: false)

                if !additions.isEmpty {
                    Button(isSaving ? "Adding..." : "Add") {
                        if !isSaving { Haptics.success() }
                        onAdd()
                    }
                    .disabled(isSaving)
                    .glassActionButton()
                }
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.top, 6)
        .onChange(of: useMetricUnits) { _, newValue in
            additions.snapWater(useMetricUnits: newValue)
        }
    }

    // MARK: - Rows

    private func sliderRow(
        systemImage: String,
        tint: Color,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        display: String,
        accessibility: String,
        gate: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center) {
            Image(systemName: systemImage)
                .foregroundStyle(tint.gradient)
                .frame(width: 30)
                .accessibilityHidden(true)
            Slider(value: snapping(value, step: step, in: range), in: range, step: step)
                .tint(tint)
                .onChange(of: value.wrappedValue) { _, _ in tick(gate) }
            AmountPill(text: display, tint: tint)
                .frame(width: 140, alignment: .trailing)
                .animation(.snappy(duration: 0.2), value: value.wrappedValue)
                .accessibilityLabel(accessibility)
        }
    }

    /// Energy is stored as kcal; metric users see kilojoules.
    @ContentBuilder
    private var foodRow: some View {
        let kJ = UnitConversion.kilocaloriesToKilojoules
        if useMetricUnits {
            let binding = Binding(
                get: { additions.foodKilocalories * kJ },
                set: { additions.foodKilocalories = $0 / kJ }
            )
            let range = 0...(IntakeAdditions.foodRangeKilocalories.upperBound * kJ)
            sliderRow(
                systemImage: "fork.knife",
                tint: .orange,
                value: binding,
                range: range,
                step: IntakeAdditions.foodStepKilocalories * kJ,
                display: "+\(Int((additions.foodKilocalories * kJ).rounded())) kJ",
                accessibility: "Add \(Int((additions.foodKilocalories * kJ).rounded())) kilojoules of energy",
                gate: $foodGate
            )
        } else {
            sliderRow(
                systemImage: "fork.knife",
                tint: .orange,
                value: $additions.foodKilocalories,
                range: IntakeAdditions.foodRangeKilocalories,
                step: IntakeAdditions.foodStepKilocalories,
                display: "+\(Int(additions.foodKilocalories)) kcal",
                accessibility: "Add \(Int(additions.foodKilocalories)) kilocalories of energy",
                gate: $foodGate
            )
        }
    }

    // MARK: - Helpers

    /// Snaps a Double binding to a fixed step within a range (works around the iOS 26
    /// Slider step regression).
    private func snapping(_ binding: Binding<Double>, step: Double, in range: ClosedRange<Double>) -> Binding<Double> {
        Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = UnitConversion.snap($0, toStep: step, in: range) }
        )
    }

    private func waterDisplay(_ liters: Double) -> String {
        if useMetricUnits {
            return String(format: "+%.1f L", liters)
        }
        return "+\(Int((liters * UnitConversion.litersToFluidOunces).rounded())) oz"
    }

    private var sleepDisplay: String {
        Duration.seconds(Int(additions.sleepHours * 3600)).formatted(.time(pattern: .hourMinute))
    }

    /// A debounced tick so slider drags don't spam haptics.
    private func tick(_ gate: Binding<Bool>) {
        guard !gate.wrappedValue else { return }
        gate.wrappedValue = true
        Haptics.lightImpact()
        Task {
            try? await Task.sleep(for: .seconds(0.15))
            gate.wrappedValue = false
        }
    }
}

private struct AmountPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .contentTransition(.numericText())
    }
}

#if DEBUG
#Preview("Imperial") {
    struct PreviewView: View {
        @State var additions = IntakeAdditions(waterLiters: 0.5, caffeineMg: 120, foodKilocalories: 500, sleepHours: 1)
        var body: some View {
            IntakeEditorView(additions: $additions, isSaving: false, errorMessage: nil, onAdd: {}, onCancel: {})
        }
    }
    return PreviewView().padding()
}
#endif

#if DEBUG
#Preview("Error") {
    struct PreviewView: View {
        @State var additions = IntakeAdditions(caffeineMg: 200)
        var body: some View {
            IntakeEditorView(additions: $additions, isSaving: false, errorMessage: "Example error", onAdd: {}, onCancel: {})
        }
    }
    return PreviewView().padding()
}
#endif
#endif
