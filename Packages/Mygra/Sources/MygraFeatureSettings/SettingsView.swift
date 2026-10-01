//
//  SettingsView.swift
//  MygraFeatureSettings
//
//  Grouped the way iOS Settings is: profile, iCloud, preferences, dashboard, tags,
//  data (export / delete), about, and the DEBUG developer tools. Every row leads with
//  a tinted icon tile and destructive actions carry the destructive role.
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
    @Environment(ToastManager.self) private var toastManager

    @AppStorage(AppStorageKeys.useMetricUnits) private var useMetricUnits: Bool = false
    @AppStorage(AppStorageKeys.useDayMonthYearDates) private var useDayMonthYearDates: Bool = false

    @State private var viewModel = ViewModel()

    public init() {}

    public var body: some View {
        Form {
            profileSection
            CloudSyncSection()
            preferencesSection
            dashboardSection
            tagsSection
            dataSection
            aboutSection
            disclaimerSection
            #if DEBUG
            developerSection
            #endif
        }
        .formStyle(.grouped)
        .sheet(isPresented: $viewModel.isEditingUser) {
            UserEditSheet(user: userData.currentUser ?? User()) { edited in
                userData.apply(edited)
            }
        }
        .sheet(isPresented: $viewModel.showDocumentPicker) {
            if let url = viewModel.exportURL {
                DocumentPickerView(url: url) {
                    viewModel.cleanupExport()
                }
            }
        }
        .sheet(isPresented: $viewModel.showingFarewell) {
            FarewellView()
                .interactiveDismissDisabled()
                .presentationDetents([.medium])
        }
        .alert("Export Failed", isPresented: Binding(get: { viewModel.exportError != nil }, set: { _ in viewModel.exportError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.exportError ?? "Unknown error")
        }
        .confirmationDialog("Delete All Migraines?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete All Migraines", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All migraines will be removed from every iCloud-enabled device. Data contributed to Apple Health stays in Apple Health.")
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            Button {
                Haptics.lightImpact()
                viewModel.isEditingUser = true
            } label: {
                HStack(spacing: Brand.Space.md) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 44))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(LinearGradient.mygra)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profileName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(profileSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, Brand.Space.xs)
            }
            .buttonStyle(.plain)
            .hoverHighlight()
            .accessibilityLabel(Text("Profile: \(profileName)"))
            .accessibilityHint("Edits your profile used for personalized insights")
        }
    }

    private var profileName: String {
        let name = userData.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "Your Profile") : name
    }

    private var profileSubtitle: String {
        guard let user = userData.currentUser else { return String(localized: "Add details to personalize insights") }
        let age = Calendar.current.dateComponents([.year], from: user.birthday, to: Date()).year ?? 0
        return String(localized: "\(user.biologicalSex.displayName), \(age) years old")
    }

    private var preferencesSection: some View {
        Section {
            Toggle(isOn: hapticBinding($useMetricUnits)) {
                Label("Use Metric Units", systemImage: "ruler")
                    .labelStyle(.settingsIcon(.green))
            }
            .tint(.green)
            .accessibilityHint("Switch between imperial and metric units for measurements")

            Toggle(isOn: hapticBinding($useDayMonthYearDates)) {
                Label("Day–Month–Year Dates", systemImage: "calendar.badge.clock")
                    .labelStyle(.settingsIcon(.teal))
            }
            .tint(.teal)
            .accessibilityHint("Switch between Month–Day–Year and Day–Month–Year formats for dates.")
        } header: {
            Text("Preferences")
        }
    }

    private var dashboardSection: some View {
        Section {
            NavigationLink(value: SettingsDestination.dashboardStats) {
                Label("Dashboard Stats", systemImage: "square.grid.2x2.fill")
                    .labelStyle(.settingsIcon(.pink))
            }
            .hoverHighlight()
        } header: {
            Text("Dashboard")
        } footer: {
            Text("Choose and arrange the Health stats shown on the Today card.")
        }
    }

    private var tagsSection: some View {
        Section {
            NavigationLink(value: SettingsDestination.tags) {
                Label("Manage Tags", systemImage: "tag.fill")
                    .labelStyle(.settingsIcon(.mygraPurple))
            }
            .hoverHighlight()
        } header: {
            Text("Tags")
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                export()
            } label: {
                HStack {
                    Label("Export Migraines as PDF", systemImage: "doc.richtext.fill")
                        .labelStyle(.settingsIcon(.orange))
                    Spacer()
                    if viewModel.isExporting {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(viewModel.isExporting || migraineData.migraines.isEmpty)
            .hoverHighlight()
            .accessibilityHint("Builds a PDF report you can save or share")

            Button(role: .destructive) {
                Haptics.lightImpact()
                viewModel.showDeleteConfirmation = true
            } label: {
                Label("Delete All Migraines", systemImage: "trash.fill")
                    .labelStyle(.settingsIcon(.red))
            }
            .disabled(!cloudSync.isOnline || migraineData.migraines.isEmpty)
            .hoverHighlight()
            .accessibilityHint("Requires an internet connection to delete your iCloud data.")
        } header: {
            Text("Data")
        } footer: {
            if !cloudSync.isOnline {
                Label("Deleting migraines requires an internet connection because they are stored in iCloud.", systemImage: "wifi.slash")
            } else if migraineData.migraines.isEmpty {
                Text("Log a migraine to enable export and deletion.")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(ViewModel.appVersion)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } label: {
                Label("Version", systemImage: "info.circle.fill")
                    .labelStyle(.settingsIcon(.gray))
            }
            creditRow(title: "Developer", name: "Nick Molargik", url: "https://www.linkedin.com/in/nicholas-molargik/", systemImage: "hammer.fill", tint: .mygraBlue)
            creditRow(title: "Graphics", name: "Rahul Parmar", url: "https://www.linkedin.com/in/rpn4499/", systemImage: "paintpalette.fill", tint: .mygraPurple)
            creditRow(title: "Publisher", name: "Molargik Software LLC", url: "https://www.molargiksoftware.com", systemImage: "building.2.fill", tint: .indigo)
        } header: {
            Text("About Mygra")
        }
    }

    private func creditRow(title: LocalizedStringKey, name: String, url: String, systemImage: String, tint: Color) -> some View {
        LabeledContent {
            Link(destination: URL(string: url)!) {
                HStack(spacing: Brand.Space.xs) {
                    Text(name)
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.mygraBlue)
            .hoverHighlight()
            .accessibilityLabel(Text("\(name), opens in browser"))
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.settingsIcon(tint))
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text("Mygra may use on‑device intelligence to generate wellness insights. These insights are provided for informational purposes only and do not constitute medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional with any questions about your health. Do not ignore or delay seeking professional care because of something you read in this app. If you are experiencing a medical emergency, call your local emergency number immediately.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("Medical Disclaimer")
        }
    }

    #if DEBUG
    private var developerSection: some View {
        Section {
            Button {
                viewModel.showSampleDataConfirmation = true
                Haptics.lightImpact()
            } label: {
                Label("Generate Test Data", systemImage: "flask.fill")
                    .labelStyle(.settingsIcon(.purple))
            }
            .alert("Generate Test Data?", isPresented: $viewModel.showSampleDataConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Generate") {
                    migraineData.generateSampleData()
                    Haptics.success()
                }
            } message: {
                Text("This will create 12-15 sample migraines with tags, intensity samples, health data, and weather data spread over the last 4 weeks. This is useful for testing features like the calendar, intensity charts, and insights.")
            }
        } header: {
            Label("Developer Tools", systemImage: "hammer.fill")
        } footer: {
            Text("Debug build only. Creates sample data to test calendar, intensity tracking, tags, and insights features.")
        }
    }
    #endif

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
        Haptics.lightImpact()
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
            Haptics.error()
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
            toastManager.showSuccess(String(localized: "All migraines deleted"))
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
            return "\(version) (\(build))"
        }

        func cleanupExport() {
            if let exportURL {
                try? FileManager.default.removeItem(at: exportURL)
            }
            exportURL = nil
        }
    }
}

// MARK: - iCloud

/// Live iCloud status with a manual "Sync Now" action and honest footers for the
/// signed-out and offline cases.
private struct CloudSyncSection: View {
    @Environment(CloudSyncManager.self) private var cloudSync
    @State private var isSyncingManually = false

    private var statusColor: Color {
        switch cloudSync.syncStatus {
        case .idle: .secondary
        case .syncing: .mygraBlue
        case .synced: .green
        case .error: .orange
        case .offline, .unavailable: .secondary
        }
    }

    private var canSync: Bool {
        cloudSync.isCloudAvailable && cloudSync.isOnline && !cloudSync.isSyncing && !isSyncingManually
    }

    var body: some View {
        Section {
            HStack(spacing: Brand.Space.md) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud")
                        Text(cloudSync.syncStatus.displayText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.opacity)
                    }
                } icon: {
                    Image(systemName: cloudSync.syncStatus.systemImage)
                        .contentTransition(.symbolEffect(.replace))
                }
                .labelStyle(.settingsIcon(statusColor))

                Spacer()

                if cloudSync.isSyncing || isSyncingManually {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Syncing")
                } else {
                    Button {
                        Task { await syncNow() }
                    } label: {
                        Label("Sync Now", systemImage: "arrow.clockwise")
                            .labelStyle(.titleOnly)
                            .font(.subheadline.weight(.semibold))
                    }
                    .glassActionButton(tint: .mygraBlue, prominent: false)
                    .controlSize(.small)
                    .disabled(!canSync)
                    .hoverHighlight()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("iCloud sync status"))
            .accessibilityValue(cloudSync.syncStatus.displayText)
        } header: {
            Text("Backup & Sync")
        } footer: {
            if !cloudSync.isCloudAvailable {
                Text("Sign in to iCloud in Settings to back up and sync your migraines across devices.")
            } else if !cloudSync.isOnline {
                Text("You're offline. Changes sync automatically when you reconnect.")
            } else if cloudSync.syncStatus.isError {
                Text("iCloud reported a problem. Changes stay on this device and retry automatically.")
            } else {
                Text("Migraines, tags, and your profile sync privately through your iCloud account.")
            }
        }
    }

    private func syncNow() async {
        Haptics.lightImpact()
        isSyncingManually = true
        defer { isSyncingManually = false }
        await cloudSync.triggerSync()
        if cloudSync.syncStatus.isError { Haptics.error() } else { Haptics.success() }
    }
}

// MARK: - Farewell

/// Shown while delete-all runs so the user sees the deletion happen.
private struct FarewellView: View {
    var body: some View {
        ZStack {
            LinearGradient.mygraWash.ignoresSafeArea()
            VStack(spacing: Brand.Space.lg) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 44))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.mygraPurple)
                    .symbolEffect(.pulse, options: .repeating)
                    .accessibilityHidden(true)
                Text("Deleting your migraines from iCloud now.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("This may take a moment.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ProgressView()
            }
            .padding(Brand.Space.xl)
        }
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
            .formStyle(.grouped)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
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
        .presentationSizing(.page)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .tags: TagManagementView()
                case .dashboardStats: DashboardStatsSettingsView()
                }
            }
    }
    .previewEnvironment()
}
#endif
