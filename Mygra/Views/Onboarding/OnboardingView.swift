//
//  OnboardingView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @State private var viewModel: OnboardingView.ViewModel = OnboardingView.ViewModel()
    var proceedForward: () -> Void
    @Environment(WeatherManager.self) private var weatherManager: WeatherManager
    @Environment(HealthManager.self) private var healthManager: HealthManager
    @Environment(NotificationManager.self) private var notificationManager: NotificationManager
    @Environment(UserManager.self) private var userManager: UserManager
    
    var body: some View {
        VStack {
            Group {
                ZStack {
                    pageView()
                        .id(viewModel.currentPage) // important for transition
                        .transition(viewModel.isMovingForward ? viewModel.forwardTransition : viewModel.backwardTransition)
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentPage)
                
                Spacer()
                
                HStack {
                    if viewModel.currentPage != .health && viewModel.currentPage != .complete {
                        Button("Back") {
                            lightTap()
                            viewModel.isMovingForward = false
                            let previous = viewModel.currentPage.previous
                            withAnimation {
                                viewModel.currentPage = previous
                            }
                        }
                        .frame(width: 80)
                        .foregroundStyle(.white)
                        .bold()
                        .padding()
                        .glassEffect(.regular.interactive().tint(.red))
                    }
                    
                    Spacer()
                    
                    if viewModel.currentPage != .complete {
                        Button("Next") {
                            lightTap()
                            if viewModel.currentPage == .user {
                                userManager.createOrReplace(newUser: viewModel.newUser)
                            }
                            let allowed = viewModel.criteriaMet(healthManager: healthManager, weatherManager: weatherManager)
                            viewModel.isMovingForward = true
                            let next = viewModel.currentPage.next
                            withAnimation {
                                viewModel.currentPage = next
                            }
                            if allowed {
                                successTap()
                            }
                        }
                        .frame(width: 80)
                        .foregroundStyle(.white)
                        .bold()
                        .padding()
                        .glassEffect(.regular.interactive().tint(viewModel.criteriaMet(healthManager: healthManager, weatherManager: weatherManager) ? .blue : .gray))
                        .disabled(!viewModel.criteriaMet(healthManager: healthManager, weatherManager: weatherManager))
                    }
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private func pageView() -> some View {
        switch viewModel.currentPage {
        case .health:
            OnboardingHealthView(viewModel: viewModel)
        case .location:
            OnboardingLocationView(viewModel: viewModel, onLocationAuthorized: { locationManager in
                self.weatherManager.setLocationProvider(locationManager)
            })
        case .notifications:
            OnboardingNotificationView(viewModel: viewModel)
                .onAppear {
                    Task {
                        viewModel.notificationsAuthorized = await notificationManager.isAuthorized
                    }
                }
        case .user:
            OnboardingUserView(viewModel: viewModel)
        case .complete:
            OnboardingCompleteView(viewModel: viewModel, finishOnboarding: {
                successTap()
                proceedForward()
            })
        }
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
        container = try ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }
    let previewUserManager = UserManager(context: container.mainContext)
    let previewHealthManager = HealthManager()
    let previewWeatherManager = WeatherManager()
    let previewNotificationManager = NotificationManager()
    let previewLocationManager = LocationManager()
    
    return OnboardingView(proceedForward: {})
        .modelContainer(container)
        .environment(previewUserManager)
        .environment(previewWeatherManager)
        .environment(previewHealthManager)
        .environment(previewLocationManager)
        .environment(previewNotificationManager)
}
