//
//  OnboardingUserView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct OnboardingUserView: View {
    @Bindable var viewModel: OnboardingView.ViewModel

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Mygra requires some information about you to best tailor the experience and draw insights from your migraines. All of your data will be stored on your device or encrypted in iCloud.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            UserEditView(
                user: $viewModel.newUser,
                userFormComplete: $viewModel.userFormComplete,
                dismiss: { }
            )
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .navigationTitle("You")
    }
}

#Preview {
    OnboardingUserView(viewModel: OnboardingView.ViewModel())
}
