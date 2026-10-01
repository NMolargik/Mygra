//
//  SettingsView.swift
//  MygraFeatureSettings
//
//  Units, dashboard stats, tags, profile, PDF export, delete-all, about, and the DEBUG
//  developer tools.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraServices
import MygraFeatureShared

public struct SettingsView: View {
    @Environment(UserDataModel.self) private var userData
    @Environment(MigraineDataModel.self) private var migraineData
    @Environment(CloudSyncManager.self) private var cloudSync

    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false

    @State private var viewModel = ViewModel()

    public init() {}

    public var body: some View {
        Form {
            Toggle("Use Metric Units", isOn: hapticBinding($useMetricUnits))
                .tint(.green)
                .accessibilityHint("Switch between imperial and metric units for measurements")

            Toggle("Use Day–Month–Year Dates", isOn: hapticBinding($useDayMonthYearDates))
                .tint(.green)
                .accessibilityHint("Switch between Month–Day–Year and Day–Month–Year formats for dates.")

            Section("Dashboard Stats") {
                Text("Choose which health stats to display on the Today card.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(DashboardStat.healthKitStats) { stat in
                    DashboardStatToggle(stat: stat)
                }
            }

            Section("Tags") {
                NavigationLink {
                    TagManagementView()
                } label: {
                    Label("Manage Tags", systemImage: "tag.fill")
                        .foregroundStyle(.mygraPurple)
                }
            }

            Button {
                viewModel.isEditingUser = true
                Haptics.lightImpact()
            } label: {
                Text("Edit User")
                    .bold()
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)

            Button {
                export()
            } label: {
                if viewModel.isExporting {
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
            .disabled(viewModel.isExporting)
            .buttonStyle(.plain)
            .alert("Export Failed", isPresented: Binding(get: { viewModel.exportError != nil }, set: { _ in viewModel.exportError = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.exportError ?? "Unknown error")
            }
            .sheet(isPresented: $viewModel.showDocumentPicker) {
                if let url = viewModel.exportURL {
                    DocumentPickerView(url: url) {
                        viewModel.cleanupExport()
                    }
                }
            }

            Button {
                viewModel.showDeleteConfirmation = true
                Haptics.lightImpact()
            } label: {
                Text("Delete All Migraines")
                    .bold()
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .disabled(!cloudSync.isOnline)
            .accessibilityHint("Requires an internet connection to delete your iCloud data.")
            .alert("Are you sure?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) { deleteAll() }
            } message: {
                Text("""
                All migraines will be deleted from all of your iCloud-enabled devices. Some entries may linger on devices until they are refreshed.

                Data contributed to Apple Health will remain in Apple Health. Apple Health data must be removed manually from within the Apple Health application.

                Are you sure you want to proceed?
                """)
            }
            if !cloudSync.isOnline {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.secondary)
                    Text("Deleting migraines requires an internet connection because they are stored in iCloud. Connect to the internet to proceed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Mygra") {
                LabeledContent("Version") {
                    Text(ViewModel.appVersion)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Developer") {
                    Link("Nick Molargik", destination: URL(string: "https://www.linkedin.com/in/nicholas-molargik/")!)
                        .foregroundStyle(.mygraBlue)
                        .accessibilityLabel("Developer: Nick Molargik, opens LinkedIn profile")
                }
                LabeledContent("Graphics") {
                    Link("Rahul Parmar", destination: URL(string: "https://www.linkedin.com/in/rpn4499/")!)
                        .foregroundStyle(.mygraBlue)
                        .accessibilityLabel("Graphics designer: Rahul Parmar, opens LinkedIn profile")
                }
                LabeledContent("Publisher") {
                    Link("Molargik Software LLC", destination: URL(string: "https://www.molargiksoftware.com")!)
                        .foregroundStyle(.mygraBlue)
                        .accessibilityLabel("Publisher: Molargik Software LLC, opens website")
                }
            }

            Section("Medical Disclaimer") {
                Text("Mygra may use on‑device intelligence to generate wellness insights. These insights are provided for informational purposes only and do not constitute medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional with any questions about your health. Do not ignore or delay seeking professional care because of something you read in this app. If you are experiencing a medical emergency, call your local emergency number immediately.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            #if DEBUG
            Section {
                Button {
                    viewModel.showSampleDataConfirmation = true
                    Haptics.lightImpact()
                } label: {
                    Label("Generate Test Data", systemImage: "flask.fill")
                        .bold()
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                .alert("Generate Test Data?", isPresented: $viewModel.showSampleDataConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Generate") {
                        migraineData.generateSampleData()
                        Haptics.success()
                    }
                } message: {
                    Text("This will create 12-15 sample migraines with tags, intensity samples, health data, and weather data spread over the last 4 weeks. This is useful for testing features like the calendar, intensity charts, and insights.")
                }

                Text("Debug build only. Creates sample data to test calendar, intensity tracking, tags, and insights features.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Developer Tools", systemImage: "hammer.fill")
            }
            #endif
        }
        .sheet(isPresented: $viewModel.isEditingUser) {
            UserEditSheet(user: userData.currentUser ?? User()) { edited in
                userData.apply(edited)
            }
        }
        .sheet(isPresented: $viewModel.showingFarewell) {
            ZStack {
                LinearGradient.mygraWash
                VStack(spacing: 16) {
                    Text("Deleting your migraines from iCloud now.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text("This may take a moment.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    ProgressView()
                }
                .padding()
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Actions

    private func hapticBinding(_ binding: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                binding.wrappedValue = newValue
                Haptics.lightImpact()
            }
        )
    }

    private func export() {
        guard !viewModel.isExporting else { return }
        viewModel.isExporting = true
        viewModel.exportError = nil
        defer { viewModel.isExporting = false }
        do {
            let blocks = MigraineReport.blocks(
                user: userData.currentUser,
                migraines: migraineData.migraines,
                useMetricUnits: useMetricUnits,
                useDMY: useDayMonthYearDates
            )
            viewModel.exportURL = try PDFReportRenderer.writeTemporaryFile(PDFReportRenderer.render(blocks))
            viewModel.showDocumentPicker = true
            Haptics.success()
        } catch {
            viewModel.exportError = String(localized: "Could not export PDF. \(error.localizedDescription)")
        }
    }

    /// Deletes everything behind the farewell sheet, holding it for a moment so the
    /// user sees what happened.
    private func deleteAll() {
        viewModel.showingFarewell = true
        let started = Date()
        migraineData.deleteAll()
        Task {
            let remaining = max(0, 2.0 - Date().timeIntervalSince(started))
            try? await Task.sleep(for: .seconds(remaining))
            Haptics.success()
            viewModel.showingFarewell = false
        }
    }
}

// MARK: - View model

extension SettingsView {
    @MainActor
    @Observable
    final class ViewModel {
        var isEditingUser = false
        var isExporting = false
        var exportError: String?
        var exportURL: URL?
        var showDocumentPicker = false
        var showDeleteConfirmation = false
        var showingFarewell = false
        var showSampleDataConfirmation = false

        static var appVersion: String {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
            let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "—"
            return "\(version) (Build \(build))"
        }

        func cleanupExport() {
            if let exportURL {
                try? FileManager.default.removeItem(at: exportURL)
            }
            exportURL = nil
        }
    }
}

// MARK: - Dashboard stat toggle

private struct DashboardStatToggle: View {
    let stat: DashboardStat
    @AppStorage private var isVisible: Bool

    init(stat: DashboardStat) {
        self.stat = stat
        _isVisible = AppStorage(wrappedValue: stat.defaultVisibility, stat.storageKey)
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isVisible },
            set: { newValue in
                isVisible = newValue
                Haptics.lightImpact()
            }
        )) {
            Label(stat.displayName, systemImage: stat.systemImage)
                .foregroundStyle(stat.color)
        }
        .tint(stat.color)
    }
}

// MARK: - User edit sheet

/// Edits a scratch copy of the profile and hands it back on Save.
private struct UserEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: User
    let onSave: (User) -> Void

    init(user: User, onSave: @escaping (User) -> Void) {
        let draft = User()
        draft.apply(user)
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                UserEditView(user: draft)
            }
            .navigationTitle("Edit User")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        Haptics.lightImpact()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        Haptics.success()
                        dismiss()
                    }
                    .tint(.mygraBlue)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .navigationTitle("Settings")
    }
    .previewEnvironment()
}
#endif
