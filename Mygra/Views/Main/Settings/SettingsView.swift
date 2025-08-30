//
//  SettingsView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("useMetricUnits") private var useMetricUnits: Bool = false
    @Environment(UserManager.self) private var userManager: UserManager
    
    @State private var editingUser: Bool = false
    
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "—"
        return "Version \(version) (Build \(build))"
    }
    
    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "—"
    }
    
    var body: some View {
        @Bindable var manager = userManager
        
        // Provide a safe Binding<User> for the editor.
        // - get: return the existing user if present; otherwise a temporary User()
        // - set: if a real user exists, apply mutations via UserManager.update(_:)
        //        (no-op if nil to protect against unexpected absence)
        let userBinding: Binding<User> = Binding(
            get: {
                manager.currentUser ?? User()
            },
            set: { updated in
                manager.update { existing in
                    // Copy fields from updated into the existing managed User
                    existing.name = updated.name
                    existing.birthday = updated.birthday
                    existing.biologicalSex = updated.biologicalSex
                    existing.heightMeters = updated.heightMeters
                    existing.weightKilograms = updated.weightKilograms
                    existing.averageSleepHours = updated.averageSleepHours
                    existing.averageCaffeineMg = updated.averageCaffeineMg
                    existing.chronicConditions = updated.chronicConditions
                    existing.dietaryRestrictions = updated.dietaryRestrictions
                }
            }
        )
        
        Form {
            Toggle("Use Metric Units", isOn: $useMetricUnits)
            
            // Edit/Save button replaces the toggle
            Button {
                if editingUser {
                    // Save changes explicitly and exit editing mode
                    let updated = userBinding.wrappedValue
                    manager.update { existing in
                        existing.name = updated.name
                        existing.birthday = updated.birthday
                        existing.biologicalSex = updated.biologicalSex
                        existing.heightMeters = updated.heightMeters
                        existing.weightKilograms = updated.weightKilograms
                        existing.averageSleepHours = updated.averageSleepHours
                        existing.averageCaffeineMg = updated.averageCaffeineMg
                        existing.chronicConditions = updated.chronicConditions
                        existing.dietaryRestrictions = updated.dietaryRestrictions
                    }
                    editingUser = false
                } else {
                    // Enter editing mode
                    editingUser = true
                }
            } label: {
                Text(editingUser ? "Save User" : "Edit User")
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .tint(editingUser ? .green : .blue)
            
            if (editingUser) {
                UserEditView(
                    user: userBinding,
                    userFormComplete: .constant(true),
                    dismiss: {
                        // If you want dismiss to cancel, you could:
                        // editingUser = false
                    }
                )
            }
            
            Section("Mygra") {
                LabeledContent("App") {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Developer") {
                    Link("Nick Molargik", destination: URL(string: "https://www.linkedin.com/in/nicholas-molargik/")!)
                        .foregroundStyle(.blue)
                }
                LabeledContent("Business") {
                    Link("Molargik Software LLC", destination: URL(string: "https://www.molargiksoftware.com")!)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

#Preview {
    let container: ModelContainer
    do {
        // Mirror the app schema but use an in-memory store for previews
        container = try ModelContainer(
            for: User.self, Migraine.self, WeatherData.self, HealthData.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }
    
    let previewUserManager = UserManager(context: container.mainContext)
    
    return SettingsView()
        .modelContainer(container)
        .environment(previewUserManager)
}
