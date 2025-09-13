//
//  SplashView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct SplashView: View {
    @Environment(UserManager.self) private var userManager: UserManager

    var proceedForward: () -> Void
    var refreshUser: () async -> Void
    var viewModel = SplashView.ViewModel()

    @State private var showReturningUserModal: Bool = false
    @State private var isSyncingFromCloud: Bool = false
    @State private var lastSyncError: String? = nil

    var body: some View {
        VStack() {
            Text("Mygra")
                .font(.system(size: 60))
                .bold()
                .opacity(viewModel.titleVisible ? 1 : 0)
                .scaleEffect(viewModel.titleVisible ? 1 : 0.7)
                .animation(.easeOut(duration: 0.6), value: viewModel.titleVisible)
                .padding(.bottom, 5)

            Text("Migraines tracked, insights generated!")
                .font(.title3)
                .opacity(viewModel.subtitleVisible ? 1 : 0)
                .offset(y: viewModel.subtitleVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.8), value: viewModel.subtitleVisible)

            Spacer()
            
            Image("mygra_head")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 250)
                .opacity(viewModel.subtitleVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(1.1), value: viewModel.subtitleVisible)
            
            Spacer()
            
            Text("Oh! You're new here.")
                .font(.headline)
                .opacity(viewModel.subtitleVisible ? 1 : 0)
                .offset(y: viewModel.subtitleVisible ? 0 : 30)
                .animation(.easeOut(duration: 0.6).delay(1.1), value: viewModel.subtitleVisible)

            Button("Get Started") {
                lightTap()
                successTap()
                proceedForward()
            }
            .foregroundStyle(.white)
            .padding()
            .font(.title)
            .bold()
            .frame(width: 200)
            .glassEffect(.regular.interactive().tint(.red))
            .opacity(viewModel.buttonVisible ? 1 : 0)
            .scaleEffect(viewModel.buttonVisible ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.9), value: viewModel.buttonVisible)
            
            Button("No, I'm not new!") {
                lightTap()
                lastSyncError = nil
                showReturningUserModal = true
                Task { await attemptCloudRefresh() }
            }
            .foregroundStyle(.blue)
            .padding()
            .opacity(viewModel.buttonVisible ? 1 : 0)
            .scaleEffect(viewModel.buttonVisible ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.9), value: viewModel.buttonVisible)
        }
        .onAppear {
            viewModel.activateAnimation()
        }
        .sheet(isPresented: $showReturningUserModal) {
            ReturningUserModal(
                isSyncing: $isSyncingFromCloud,
                errorMessage: $lastSyncError,
                onRetry: {
                    lightTap()
                    Task { await attemptCloudRefresh() }
                },
                onClose: {
                    lightTap()
                    showReturningUserModal = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .padding(.top, 80)
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

    @MainActor
    private func attemptCloudRefresh() async {
        isSyncingFromCloud = true
        lastSyncError = nil
        defer { isSyncingFromCloud = false }

        // Re-fetch local state first
        await userManager.refresh()
        // Try another iCloud restore attempt (slightly longer timeout to improve chances)
        await userManager.restoreFromCloud(timeout: 2, pollInterval: 1.0)

        if userManager.currentUser != nil {
            successTap()
            // Let outer flow proceed (mirrors ContentView.refreshUser behavior)
            await refreshUser()
        } else {
            // Keep the modal open; provide a soft message to encourage retry later
            lastSyncError = "No user found yet. iCloud may take a bit longer to deliver your data."
        }
    }

    private struct ReturningUserModal: View {
        @Binding var isSyncing: Bool
        @Binding var errorMessage: String?
        var onRetry: () -> Void
        var onClose: () -> Void

        var body: some View {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Welcome back!")
                        .font(.title2).bold()
                    Text("If you started on another Apple device, it can take up to 30 minutes for the initial sync to occur.")
                        .foregroundStyle(.secondary)

                    if isSyncing {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Checking iCloud for your data…")
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }

                    if let msg = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(msg)
                                .font(.footnote)
                        }
                    }

                    Spacer()

                    HStack {
                        Button("Close") { onClose() }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.red)

                        Spacer()

                        Button("Retry") { onRetry() }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(.blue)
                            .disabled(isSyncing)
                    }
                }
                .padding()
                .navigationTitle("Sync from iCloud")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview {
    SplashView(proceedForward: {}, refreshUser: {})
}
