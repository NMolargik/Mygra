//
//  UserEditView.swift
//  MygraFeatureSettings
//
//  Form sections that edit a `User` in place (onboarding and Settings).
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
    @FocusState private var isFirstNameFocused: Bool
    @FocusState private var isAddingConditionFocused: Bool
    @FocusState private var isAddingRestrictionFocused: Bool

    public init(user: User) {
        self.user = user
    }

    public var body: some View {
        Section("First Name") {
            TextField("First Name", text: $user.name)
                .focused($isFirstNameFocused)
        }

        Section("Birthday") {
            DatePicker("Birthday", selection: $user.birthday, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.mygraPurple)
                .onChange(of: user.birthday) { isFirstNameFocused = false }
        }

        Section("Anatomy") {
            Toggle("Use Metric Units", isOn: $useMetricUnits)
                .tint(.green)

            Picker("Biological Sex", selection: $user.biologicalSex) {
                ForEach(BiologicalSex.allCases, id: \.self) { sex in
                    Text(sex.displayName).tag(sex)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Height:")
                Spacer()
                if useMetricUnits {
                    Stepper(value: $user.heightCentimeters, in: 100...220, step: 1) {
                        Text("\(Int(user.heightCentimeters)) cm")
                    }
                } else {
                    Stepper(value: $user.heightInches, in: 48...84, step: 1) {
                        let feet = Int(user.heightInches) / 12
                        let inches = Int(user.heightInches) % 12
                        Text("\(feet)' \(inches)\"")
                    }
                }
            }

            HStack {
                Text("Weight:")
                Spacer()
                if useMetricUnits {
                    Picker("Weight (kg)", selection: Binding(get: { Int(user.weightKilograms) }, set: { user.weightKilograms = Double($0) })) {
                        ForEach(35...200, id: \.self) { value in
                            Text("\(value) kg").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: 120)
                    .frame(height: 100)
                } else {
                    Picker("Weight (lbs)", selection: Binding(get: { Int(user.weightPounds) }, set: { user.weightPounds = Double($0) })) {
                        ForEach(80...440, id: \.self) { value in
                            Text("\(value) lbs").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: 120)
                    .frame(height: 100)
                }
            }
        }

        Section("Intake Stats") {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                Stepper(
                    value: Binding(
                        get: { user.averageCaffeineMg / UnitConversion.caffeineMgPerCup },
                        set: { user.averageCaffeineMg = $0 * UnitConversion.caffeineMgPerCup }
                    ),
                    in: 0...10,
                    step: 1
                ) {
                    Text("\(Int(user.averageCaffeineMg / UnitConversion.caffeineMgPerCup)) cups (\(Int(user.averageCaffeineMg)) mg)")
                }
            }
            Stepper(value: $user.averageSleepHours, in: 0...12, step: 0.5) {
                Text("Sleep: \(String(format: "%.1f", user.averageSleepHours)) hrs")
            }
        }

        Section("Chronic Conditions") {
            ListEditor(
                items: $user.chronicConditions,
                newItem: $newCondition,
                placeholder: "Add Condition",
                focus: $isAddingConditionFocused
            )
        }

        Section("Dietary Restrictions") {
            ListEditor(
                items: $user.dietaryRestrictions,
                newItem: $newDietaryRestriction,
                placeholder: "Add Restriction",
                focus: $isAddingRestrictionFocused
            )
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
                .onSubmit {
                    add()
                    focus.wrappedValue = true
                }
            if !newItem.isEmpty {
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title)
                }
                .buttonStyle(.borderless)
            }
        }
        ForEach(items, id: \.self) { item in
            HStack {
                Text(item)
                Spacer()
                Button(role: .destructive) {
                    items.removeAll { $0 == item }
                } label: {
                    Image(systemName: "trash")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func add() {
        let trimmed = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(trimmed)
        newItem = ""
    }
}

#Preview {
    Form {
        UserEditView(user: User(name: "Nick"))
    }
}
#endif
