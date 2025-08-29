//
//  OnboardingView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    var viewModel: OnboardingView.ViewModel = OnboardingView.ViewModel()
    var proceedForward: () -> Void
    @Environment(WeatherManager.self) private var weatherManager: WeatherManager
    @Environment(HealthManager.self) private var healthManager: HealthManager
    @Environment(NotificationManager.self) private var notificationManager: NotificationManager
    @Environment(UserManager.self) private var userManager: UserManager
    
    @State private var notificationsAuthorized = false
    
    var body: some View {
        VStack {
            Group {
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
                                self.notificationsAuthorized = await notificationManager.isAuthorized
                            }
                        }
                case .user:
                    OnboardingUserView(viewModel: viewModel)
                case .complete:
                    OnboardingCompleteView(viewModel: viewModel, finishOnboarding: {
                        proceedForward()
                    })
                }
                
                Spacer()
                
                HStack {
                    if viewModel.currentPage != .health && viewModel.currentPage != .complete {
                        Button("Back") {
                            viewModel.currentPage = viewModel.currentPage.previous
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
                            if viewModel.currentPage == .user {
                                userManager.createOrReplace(newUser: viewModel.newUser)
                            }
                            
                            viewModel.currentPage = viewModel.currentPage.next
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
