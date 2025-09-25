//
//  SettingsView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData
import Network

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserManager.self) private var userManager: UserManager

    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false
    
    var onDeletionTriggered: () -> Void

    @State private var editingUser: Bool = false
    @State private var exportTempURL: URL?
    @State private var showDocumentPicker: Bool = false
    @State private var isExporting: Bool = false
    @State private var exportError: String?
    @State private var showDeleteConfirmation: Bool = false
    @State private var showingFarewell: Bool = false
    @State private var isOnline: Bool = true
    @State private var networkMonitor: NWPathMonitor?

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
                    Haptics.lightImpact()
                }
            ))
            .tint(.green)

            Toggle("Use Day–Month–Year Dates", isOn: Binding(
                get: { useDayMonthYearDates },
                set: { newValue in
                    useDayMonthYearDates = newValue
                    Haptics.lightImpact()
                }
            ))
            .tint(.green)
            .accessibilityHint("Switch between Month–Day–Year and Day–Month–Year formats for dates.")

            Button {
                editingUser = true
                Haptics.lightImpact()
            } label: {
                Text("Edit User")
                    .bold()
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)


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
                        .foregroundStyle(.orange)
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
            
            Button {
                showDeleteConfirmation = true
                Haptics.lightImpact()
            } label: {
                Text("Delete All Data")
                    .bold()
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .disabled(!isOnline)
            .accessibilityHint("Requires an internet connection to delete your iCloud data.")
            .alert("Are you sure?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                    .tint(.blue)
                Button("Proceed", role: .destructive) {
                    presentFarewellFlow()
                }
            } message: {
                Text("""
All migraines will be deleted from all of your iCloud-enabled devices. Some entries may linger on devices until they are refreshed.
Your user information will also be deleted from iCloud. Any future attempt to use Mygra will require a new registration.

Data contributed to Apple Health will remain in Apple Health. Even deletion of the application from your device will not remove that data. Apple Health data must be removed manually from within the Apple Health application.

Are you sure you want to proceed?
""")
            }
            if !isOnline {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.secondary)
                    Text("Deleting your data requires an internet connection because it’s stored in iCloud. Connect to the internet to proceed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                LabeledContent("Publisher") {
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
        .sheet(isPresented: $editingUser) {
            NavigationStack {
                Form {
                    UserEditView(
                        user: userBinding,
                        userFormComplete: .constant(true),
                        dismiss: {
                            editingUser = false
                        }
                    )
                }
                .navigationTitle("Edit User")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editingUser = false
                            Haptics.lightImpact()
                        }
                        .tint(.red)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
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
                            Haptics.success()
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFarewell) {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.25), Color.black.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Text("Thank you for using Mygra. We hoped we helped, even a little.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text("We're deleting your data from iCloud now. This may take a moment.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    ProgressView()
                }
                .padding()
            }
        }
        .onAppear { startNetworkMonitoring() }
        .onDisappear { stopNetworkMonitoring() }
    }

    // MARK: - Network monitoring

    private func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isOnline = (path.status == .satisfied)
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        self.networkMonitor = monitor
    }

    private func stopNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = nil
    }

    // MARK: - Delete flow

    private func presentFarewellFlow() {
        showingFarewell = true
        onDeletionTriggered()
    }

    private func deletionFlowCompleted() {
        // TODO: Intentionally left empty; to be implemented later.
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
            Haptics.success()
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

    return SettingsView(
            onDeletionTriggered: {}
        )
        .modelContainer(container)
        .environment(previewUserManager)
}
