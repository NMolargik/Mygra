//
//  OnboardingUserPage.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import SwiftUI

struct OnboardingUserPage: View {
    @Bindable var viewModel: OnboardingView.ViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.mygraBlue)
                        .accessibilityHidden(true)

                    Text("About You")
                        .font(.title.bold())

                    Text("Tell us a bit about yourself so Mygra can personalize insights and track patterns. All data stays on your device or encrypted in iCloud.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 24)

                // Form content
                Form {
                    UserEditView(
                        user: $viewModel.newUser,
                        userFormComplete: $viewModel.userFormComplete,
                        dismiss: { }
                    )
                }
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 1600)
                .frame(maxWidth: 500)

                Spacer(minLength: 120)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    OnboardingUserPage(viewModel: OnboardingView.ViewModel())
}
