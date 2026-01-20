//
//  OnboardingView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData
import UIKit

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var viewModel = ViewModel()

    private var steps: [OnboardingStep] {
        OnboardingStep.allCases
    }

    private var currentIndex: Int {
        steps.firstIndex(of: viewModel.currentStep) ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Page Indicators
            if viewModel.currentStep != .complete {
                HStack(spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        Capsule()
                            .fill(index <= currentIndex ? Color.mygraPurple : Color.secondary.opacity(0.3))
                            .frame(height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            // Content
            TabView(selection: $viewModel.currentStep) {
                OnboardingPrivacyPage()
                    .tag(OnboardingStep.privacy)
                
                OnboardingHealthPage()
                    .tag(OnboardingStep.health)
                
                OnboardingLocationPage()
                    .tag(OnboardingStep.location)
                
                OnboardingNotificationPage()
                    .tag(OnboardingStep.notification)

                OnboardingUserPage(viewModel: viewModel)
                    .tag(OnboardingStep.user)
                
                OnboardingCompletePage(onFinish: onFinished)
                    .tag(OnboardingStep.complete)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
            
            // Bottom Buttons
            if viewModel.currentStep != .complete {
                VStack(spacing: 12) {
                    // Continue Button
                    Button {
                        // Dismiss keyboard before transitioning
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        Haptics.mediumImpact()
                        viewModel.handleContinueTapped()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Continue")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.mygraPurple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Skip Button (optional steps only)
                    if viewModel.showsSkip {
                        Button {
                            Haptics.lightImpact()
                            viewModel.handleSkipTapped()
                        } label: {
                            Text("Skip for now")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            viewModel.currentStep = .privacy
        }
        .environment(viewModel)
    }
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }
    let previewUserManager = UserManager(context: container.mainContext)
    let previewHealthManager = HealthManager()
    let previewWeatherManager = WeatherManager()
    let previewNotificationManager = NotificationManager()
    let previewLocationManager = LocationManager()

    return OnboardingView(onFinished: {})
        .modelContainer(container)
        .environment(previewUserManager)
        .environment(previewWeatherManager)
        .environment(previewHealthManager)
        .environment(previewLocationManager)
        .environment(previewNotificationManager)
}
