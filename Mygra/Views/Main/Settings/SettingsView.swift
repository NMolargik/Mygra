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
    @AppStorage("useDayMonthYearDates") private var useDayMonthYearDates: Bool = false
    @Environment(UserManager.self) private var userManager: UserManager
    @Environment(\.modelContext) private var modelContext

    @State private var editingUser: Bool = false

    // Document export
    @State private var exportTempURL: URL?
    @State private var showDocumentPicker: Bool = false
    @State private var isExporting: Bool = false
    @State private var exportError: String?

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
            Toggle("Use Metric Units", isOn: Binding(
                get: { useMetricUnits },
                set: { newValue in
                    useMetricUnits = newValue
                    lightTap()
                }
            ))

            Toggle("Use Day–Month–Year Dates", isOn: Binding(
                get: { useDayMonthYearDates },
                set: { newValue in
                    useDayMonthYearDates = newValue
                    lightTap()
                }
            ))
            .accessibilityHint("Switch between Month–Day–Year and Day–Month–Year formats for dates.")

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
                    successTap()
                } else {
                    // Enter editing mode
                    editingUser = true
                    lightTap()
                }
            } label: {
                Text(editingUser ? "Save User" : "Edit User")
                    .bold()
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

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

            // Export button
            Button {
                Task {
                    await exportMigrainesAsPDF()
                }
            } label: {
                if isExporting {
                    HStack {
                        ProgressView()
                        Text("Exporting…")
                            .bold()
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("Export Migraines as PDF")
                        .bold()
                        .foregroundStyle(.red)
                }
            }
            .disabled(isExporting)
            .buttonStyle(.plain)
            .alert("Export Failed", isPresented: Binding(get: { exportError != nil }, set: { _ in exportError = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportError ?? "Unknown error")
            }
            .sheet(isPresented: $showDocumentPicker) {
                if let url = exportTempURL {
                    DocumentPickerView(url: url) {
                        // Completion: clear temp URL after picker dismisses
                        cleanupTempURL()
                    }
                }
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

            Section("Medical Disclaimer") {
                Text("""
Mygra may use on‑device intelligence to generate wellness insights. These insights are provided for informational purposes only and do not constitute medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional with any questions about your health. Do not ignore or delay seeking professional care because of something you read in this app. If you are experiencing a medical emergency, call your local emergency number immediately.
""")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Export logic

    private func exportMigrainesAsPDF() async {
        guard !isExporting else { return }
        isExporting = true
        exportError = nil

        do {
            // Fetch all migraines (most recent first)
            var desc = FetchDescriptor<Migraine>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            desc.fetchLimit = nil
            let migraines = try modelContext.fetch(desc)

            // Compose PDF data
            let user = userManager.currentUser
            let data = try PDFComposer.composePDF(
                user: user,
                migraines: migraines,
                useMetricUnits: useMetricUnits,
                useDMY: useDayMonthYearDates
            )

            // Write to a temp file
            let tmpDir = FileManager.default.temporaryDirectory
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let stamp = formatter.string(from: Date())
            let filename = "Mygra_Migraines_\(stamp).pdf"
            let fileURL = tmpDir.appendingPathComponent(filename)
            try data.write(to: fileURL, options: .atomic)

            // Present system Files save prompt
            exportTempURL = fileURL
            showDocumentPicker = true
            successTap()
        } catch {
            exportError = "Could not export PDF. \(error.localizedDescription)"
        }

        isExporting = false
    }

    private func cleanupTempURL() {
        if let url = exportTempURL {
            try? FileManager.default.removeItem(at: url)
        }
        exportTempURL = nil
    }

    // MARK: - Haptics
    private func lightTap() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        #endif
    }

    private func successTap() {
        #if os(iOS)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif
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
