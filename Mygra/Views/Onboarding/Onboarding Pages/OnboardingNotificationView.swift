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
        VStack {
            Spacer()
            
            Text("Notifications")
                .font(.largeTitle)
                .bold()
            
            Image(systemName: "bell.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .foregroundStyle(.green)
                .shadow(radius: 5)
            
            Text("Mygra connects directly to Apple Health to read and write critical health data, allowing us to track your migraines.\n\nPlease authorize all options.")
                .padding()
            
            Spacer()
            
            Button("Authorize") {
                Task {
                    await notificationManager.requestAuthorization()
                }
            }
            .foregroundStyle(.white)
            .padding()
            .font(.title)
            .bold()
            .frame(width: 200)
            .glassEffect(.regular.interactive().tint(.blue))
        }
    }
}

#Preview {
    OnboardingNotificationView(viewModel: OnboardingView.ViewModel())
}
