//
//  UserEditView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct UserEditView: View {
    @AppStorage("useMetricUnits") private var useMetricUnits: Bool = false

    @Binding var user: User
    @Binding var userFormComplete: Bool
    
    var dismiss: () -> Void
    
    @State private var newCondition: String = ""
    @State private var newDietaryRestriction: String = ""
    @FocusState private var isFirstNameFocused: Bool

    var body: some View {
        Section("First Name") {
            TextField("First Name", text: $user.name)
                .focused($isFirstNameFocused)
        }
        
        Section("Birthday") {
            DatePicker("Birthday", selection: $user.birthday, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.red)
                .onTapGesture { isFirstNameFocused = false }
                .onChange(of: user.birthday) { isFirstNameFocused = false }
        }

        Section("Anatomy") {
            Toggle("Use Metric Units", isOn: $useMetricUnits)
                .tint(.green)

            
            Picker("Biological Sex", selection: $user.biologicalSex) {
                ForEach(BiologicalSex.allCases, id: \.self) { sex in
                    Text(sex.rawValue.capitalized).tag(sex)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Height:")
                Spacer()
                if useMetricUnits {
                    let cm = user.heightCentimeters
                    Stepper(
                        value: Binding(
                            get: { cm },
                            set: { user.heightCentimeters = $0 }
                        ),
                        in: 100...220,
                        step: 1
                    ) {
                        Text("\(Int(user.heightCentimeters)) cm")
                    }
                } else {
                    let inches = user.heightInches
                    Stepper(
                        value: Binding(
                            get: { inches },
                            set: { user.heightInches = $0 }
                        ),
                        in: 48...84,
                        step: 1
                    ) {
                        let feet = Int(user.heightInches) / 12
                        let inch = Int(user.heightInches) % 12
                        Text("\(feet)' \(inch)\"")
                    }
                }
            }

            HStack {
                Text("Weight:")
                Spacer()
                if useMetricUnits {
                    Picker(
                        "Weight (kg)",
                        selection: Binding(
                            get: { Int(user.weightKilograms) },
                            set: { user.weightKilograms = Double($0) }
                        )
                    ) {
                        ForEach(35...200, id: \.self) { value in
                            Text("\(value) kg").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: 120)
                    .frame(height: 100)
                } else {
                    
                    Picker(
                        "Weight (lbs)",
                        selection: Binding(
                            get: { Int(user.weightPounds) },
                            set: { user.weightPounds = Double($0) }
                        )
                    ) {
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
                        get: { user.averageCaffeineMg / 95 },
                        set: { user.averageCaffeineMg = $0 * 95 }
                    ),
                    in: 0...10,
                    step: 1
                ) {
                    Text("\(Int(user.averageCaffeineMg / 95)) cups (\(Int(user.averageCaffeineMg)) mg)")
                }
            }
            Stepper(value: $user.averageSleepHours, in: 0...12, step: 0.5) {
                Text("Sleep: \(String(format: "%.1f", user.averageSleepHours)) hrs")
            }
        }

        Section("Chronic Conditions") {
            HStack {
                TextField("Add Condition", text: $newCondition)
                if (!newCondition.isEmpty) {
                    Button(action: {
                        let trimmed = newCondition.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            user.chronicConditions.append(trimmed)
                            newCondition = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title)
                    }
                    .buttonStyle(.borderless)
                }
            }
            ForEach(user.chronicConditions, id: \.self) { condition in
                HStack {
                    Text(condition)
                    Spacer()
                    Button(action: {
                        user.chronicConditions.removeAll(where: { $0 == condition })
                    }) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }

        Section("Dietary Restrictions") {
            HStack {
                TextField("Add Restriction", text: $newDietaryRestriction)
                if (!newDietaryRestriction.isEmpty) {
                    Button(action: {
                        let trimmed = newDietaryRestriction.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            user.dietaryRestrictions.append(trimmed)
                            newDietaryRestriction = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title)
                    }
                    .buttonStyle(.borderless)
                }
            }
            ForEach(user.dietaryRestrictions, id: \.self) { restriction in
                HStack {
                    Text(restriction)
                    Spacer()
                    Button(action: {
                        user.dietaryRestrictions.removeAll(where: { $0 == restriction })
                    }) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .onAppear { userFormComplete = true }
    }
}

#Preview {
    UserEditView(user: .constant(User()), userFormComplete: .constant(false), dismiss: {})
}

