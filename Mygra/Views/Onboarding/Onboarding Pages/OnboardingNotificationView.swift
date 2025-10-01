//
//  OnboardingNotificationView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct OnboardingNotificationView: View {
    @Bindable var viewModel: OnboardingView.ViewModel
    @Environment(NotificationManager.self) var notificationManager: NotificationManager

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            VStack(spacing: 8) {
                Text("Notifications")
                    .font(.largeTitle).bold()
                    .foregroundStyle(.white)
                    .shadow(radius: 5, x: 1, y: -1)
                
                Text("Allow notifications so Mygra can remind you to log migraines and alert you about weather conditions that might trigger them.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Image(systemName: "bell.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 180, height: 180)
                .foregroundStyle(LinearGradient(colors: [.red, .red.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(radius: 8)
                .padding(.vertical, 8)

            Spacer(minLength: 12)

            Button(action: {
                Task {
                    do {
                        try await notificationManager.requestAuthorization()
                    } catch let error as NotificationError {
                        print(error.localizedDescription)
                    } catch {
                        print("Unexpected error requesting notification authorization: \(error)")
                    }
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "bell.circle.fill")
                        .imageScale(.large)
                    Text("Continue")
                        .font(.title3).bold()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .padding(.vertical, 14)
            }
            .adaptiveGlass(tint: .mygraPurple)
            .shadow(radius: 6, y: 3)
            .padding(.horizontal)
        }
    }
}

#Preview {
    OnboardingNotificationView(viewModel: OnboardingView.ViewModel())
        .environment(NotificationManager())
}
