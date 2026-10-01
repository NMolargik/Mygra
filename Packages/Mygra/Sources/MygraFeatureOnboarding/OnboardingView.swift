//
//  OnboardingView.swift
//  MygraFeatureOnboarding
//
//  The paged permission flow. The profile drafted on the About You page is saved when
//  the user enters the app.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

public struct OnboardingView: View {
    @Environment(UserDataModel.self) private var userData

    let onFinished: () -> Void

    @State private var viewModel = ViewModel()

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    private var steps: [OnboardingStep] { OnboardingStep.allCases }
    private var currentIndex: Int { steps.firstIndex(of: viewModel.currentStep) ?? 0 }

    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.currentStep != .complete {
                HStack(spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, _ in
                        Capsule()
                            .fill(index <= currentIndex ? Color.mygraPurple : Color.secondary.opacity(0.3))
                            .frame(height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    }
                }
                .frame(maxWidth: Brand.readableWidth)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("Step \(currentIndex + 1) of \(steps.count)")
            }

            TabView(selection: $viewModel.currentStep) {
                OnboardingPrivacyPage()
                    .tag(OnboardingStep.privacy)
                OnboardingLocationPage()
                    .tag(OnboardingStep.location)
                OnboardingHealthPage()
                    .tag(OnboardingStep.health)
                OnboardingNotificationPage()
                    .tag(OnboardingStep.notification)
                OnboardingUserPage(user: viewModel.draftUser)
                    .tag(OnboardingStep.user)
                OnboardingCompletePage {
                    userData.save(viewModel.draftUser)
                    onFinished()
                }
                .tag(OnboardingStep.complete)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)

            if viewModel.currentStep != .complete {
                VStack(spacing: 12) {
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        Haptics.mediumImpact()
                        viewModel.advance()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.mygraPurple)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityHint("Moves to the next onboarding step.")

                    if viewModel.currentStep.isSkippable {
                        Button {
                            Haptics.lightImpact()
                            viewModel.skip()
                        } label: {
                            Text("Skip for now")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityHint("Skips this step and moves to the next one.")
                    }
                }
                .frame(maxWidth: Brand.readableWidth)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .background(groupedBackground)
    }
}

extension OnboardingView {
    @MainActor
    @Observable
    final class ViewModel {
        var currentStep: OnboardingStep = .privacy
        /// The profile drafted on the About You page.
        let draftUser = User()

        func advance() {
            guard let next = currentStep.next else { return }
            currentStep = next
        }

        func skip() {
            guard currentStep.isSkippable else { return }
            advance()
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
        .previewEnvironment()
}
#endif
