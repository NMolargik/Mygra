//
//  UserEditView.swift
//  MygraFeatureSettings
//
//  Form sections that edit a `User` in place (onboarding and Settings). Every control
//  is a native form row: compact date picker, menu pickers, and steppers with their
//  units spelled out, so the form reads cleanly at any width and in VoiceOver.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

public struct UserEditView: View {
    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false

    @Bindable var user: User

    @State private var newCondition = ""
    @State private var newDietaryRestriction = ""
    @FocusState private var isAddingConditionFocused: Bool
    @FocusState private var isAddingRestrictionFocused: Bool

    public init(user: User) {
        self.user = user
    }

    public var body: some View {
        Section {
            TextField("First Name", text: $user.name)
                .textContentType(.givenName)
                .submitLabel(.done)

            DatePicker("Birthday", selection: $user.birthday, in: ...Date(), displayedComponents: .date)
                .tint(.mygraPurple)

            Picker("Biological Sex", selection: $user.biologicalSex) {
                ForEach(BiologicalSex.allCases, id: \.self) { sex in
                    Text(sex.displayName).tag(sex)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Label("Basics", systemImage: "person.text.rectangle")
        } footer: {
            Text("Used to tailor insights and the migraine assistant. Everything stays on your device and in your iCloud.")
        }

        Section {
            Toggle("Use Metric Units", isOn: $useMetricUnits)
                .tint(.green)

            if useMetricUnits {
                Stepper(value: $user.heightCentimeters, in: 100...220, step: 1) {
                    LabeledContent("Height", value: "\(Int(user.heightCentimeters)) cm")
                }
                Stepper(value: $user.weightKilograms, in: 35...200, step: 1) {
                    LabeledContent("Weight", value: "\(Int(user.weightKilograms)) kg")
                }
            } else {
                Stepper(value: $user.heightInches, in: 48...84, step: 1) {
                    let feet = Int(user.heightInches) / 12
                    let inches = Int(user.heightInches) % 12
                    LabeledContent("Height", value: "\(feet)′ \(inches)″")
                }
                Stepper(value: $user.weightPounds, in: 80...440, step: 1) {
                    LabeledContent("Weight", value: "\(Int(user.weightPounds)) lbs")
                }
            }
        } header: {
            Label("Body", systemImage: "figure.stand")
        }

        Section {
            Stepper(
                value: Binding(
                    get: { user.averageCaffeineMg / UnitConversion.caffeineMgPerCup },
                    set: { user.averageCaffeineMg = $0 * UnitConversion.caffeineMgPerCup }
                ),
                in: 0...10,
                step: 1
            ) {
                LabeledContent {
                    Text("\(Int(user.averageCaffeineMg / UnitConversion.caffeineMgPerCup)) cups (\(Int(user.averageCaffeineMg)) mg)")
                } label: {
                    Label("Caffeine per day", systemImage: "cup.and.saucer.fill")
                        .labelStyle(.alignedIcon)
                }
            }
            Stepper(value: $user.averageSleepHours, in: 0...12, step: 0.5) {
                LabeledContent {
                    Text("\(user.averageSleepHours, format: .number.precision(.fractionLength(1))) hrs")
                } label: {
                    Label("Sleep per night", systemImage: "bed.double.fill")
                        .labelStyle(.alignedIcon)
                }
            }
        } header: {
            Label("Typical Intake", systemImage: "chart.bar.fill")
        } footer: {
            Text("Your usual amounts let Mygra spot days that differ from your baseline.")
        }

        Section {
            ListEditor(
                items: $user.chronicConditions,
                newItem: $newCondition,
                placeholder: "Add Condition",
                focus: $isAddingConditionFocused
            )
        } header: {
            Label("Chronic Conditions", systemImage: "stethoscope")
        }

        Section {
            ListEditor(
                items: $user.dietaryRestrictions,
                newItem: $newDietaryRestriction,
                placeholder: "Add Restriction",
                focus: $isAddingRestrictionFocused
            )
        } header: {
            Label("Dietary Restrictions", systemImage: "leaf.fill")
        }
    }
}

/// A free-text list editor: an add field plus removable rows.
private struct ListEditor: View {
    @Binding var items: [String]
    @Binding var newItem: String
    let placeholder: LocalizedStringKey
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack {
            TextField(placeholder, text: $newItem)
                .focused(focus)
                .submitLabel(.done)
                .onSubmit {
                    add()
                    focus.wrappedValue = true
                }
            if !newItem.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy, value: newItem.isEmpty)
        ForEach(items, id: \.self) { item in
            Text(item)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Haptics.lightImpact()
                        items.removeAll { $0 == item }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
        }
        .onDelete { offsets in
            items.remove(atOffsets: offsets)
        }
    }

    private func add() {
        let trimmed = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !items.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            newItem = ""
            return
        }
        Haptics.lightImpact()
        items.append(trimmed)
        newItem = ""
    }
}

#if DEBUG
#Preview {
    Form {
        UserEditView(user: User(name: "Nick"))
    }
}
#endif
#endif
