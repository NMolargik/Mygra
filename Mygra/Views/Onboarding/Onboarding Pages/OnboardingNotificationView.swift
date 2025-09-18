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
            
            Button("Continue") {
                Task {
                    do {
                        try await notificationManager.requestAuthorization()
                    } catch let error as NotificationError {
                        // Handle specific notification errors as needed
                        print(error.localizedDescription)
                    } catch {
                        // Handle any unexpected errors
                        print("Unexpected error requesting notification authorization: \(error)")
                    }
                }
            }
            .foregroundStyle(.white)
            .padding()
            .font(.title)
            .bold()
            .frame(width: 200)
            .glassEffect(.regular.interactive().tint(.red))
        }
    }
}

#Preview {
    OnboardingNotificationView(viewModel: OnboardingView.ViewModel())
}
