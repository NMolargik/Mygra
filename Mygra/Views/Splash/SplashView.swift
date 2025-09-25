//
//  SplashView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData

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
                .fontWeight(.semibold)
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
                Haptics.lightImpact()
                Haptics.success()
                proceedForward()
            }
            .foregroundStyle(.white)
            .buttonStyle(.borderedProminent)
            .padding()
            .font(.title)
            .bold()
            .tint(.red)
            .adaptiveGlass(tint: .red)
            .shadow(radius: 8, y: 3)
            .opacity(viewModel.buttonVisible ? 1 : 0)
            .scaleEffect(viewModel.buttonVisible ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.9), value: viewModel.buttonVisible)
            
            Button("No, I'm not new!") {
                Haptics.lightImpact()
                lastSyncError = nil
                showReturningUserModal = true
                Task { await attemptCloudRefresh() }
            }
            .padding(8)
            .bold()
            .adaptiveGlass(tint: .gray)
            .opacity(viewModel.buttonVisible ? 1 : 0)
            .scaleEffect(viewModel.buttonVisible ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.9), value: viewModel.buttonVisible)
        }
        .onAppear {
            viewModel.activateAnimation()
        }
        .sheet(isPresented: $showReturningUserModal) {
            ReturningUserView(
                isSyncing: $isSyncingFromCloud,
                errorMessage: $lastSyncError,
                onRetry: {
                    Haptics.lightImpact()
                    Task { await attemptCloudRefresh() }
                },
                onClose: {
                    Haptics.lightImpact()
                    showReturningUserModal = false
                }
            )
            .presentationDetents([.medium])
        }
        .padding(.top, 80)
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
            Haptics.success()
            // Let outer flow proceed (mirrors ContentView.refreshUser behavior)
            await refreshUser()
        } else {
            // Keep the modal open; provide a soft message to encourage retry later
            lastSyncError = "No user found yet. iCloud may take a bit longer to deliver your data."
        }
    }
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(
            for: User.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }

    let previewUserManager = UserManager(context: container.mainContext)

    return SplashView(proceedForward: {}, refreshUser: {})
        .modelContainer(container)
        .environment(previewUserManager)
}
