//
//  OnboardingView.swift
//  MygraFeatureOnboarding
//
//  The paged first-run flow: privacy → location → health → notifications → about you →
//  done. Every permission page is skippable (the HIG asks apps never to gate on a
//  permission) and the profile drafted on the About You page is saved on entry.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

public struct OnboardingView: View {
    @Environment(UserDataModel.self) private var userData
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let onFinished: () -> Void

    @State private var viewModel = ViewModel()

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    private var steps: [OnboardingStep] { OnboardingStep.allCases }
    private var currentIndex: Int { steps.firstIndex(of: viewModel.currentStep) ?? 0 }
    private var isComplete: Bool { viewModel.currentStep == .complete }

    public var body: some View {
        VStack(spacing: 0) {
            if !isComplete {
                progress
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
            .animation(.snappy, value: viewModel.currentStep)

            if !isComplete {
                footer
            }
        }
        .background(groupedBackground.ignoresSafeArea())
        .onChange(of: viewModel.currentStep) { _, _ in
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Chrome

    private var progress: some View {
        HStack(spacing: Brand.Space.sm) {
            ForEach(Array(steps.filter { $0 != .complete }.enumerated()), id: \.offset) { index, step in
                Capsule()
                    .fill(index <= currentIndex ? AnyShapeStyle(LinearGradient.mygraHorizontal) : AnyShapeStyle(Color.secondary.opacity(0.25)))
                    .frame(height: 4)
                    .animation(.snappy, value: currentIndex)
                    .accessibilityHidden(true)
                    .overlay(alignment: .top) {
                        if horizontalSizeClass == .regular {
                            Image(systemName: step.systemImage)
                                .font(.caption2)
                                .foregroundStyle(index <= currentIndex ? .mygraPurple : .secondary)
                                .offset(y: 10)
                                .accessibilityHidden(true)
                        }
                    }
            }
        }
        .frame(maxWidth: Brand.readableWidth)
        .padding(.horizontal, Brand.Space.xl)
        .padding(.top, Brand.Space.lg)
        .padding(.bottom, horizontalSizeClass == .regular ? Brand.Space.xl : Brand.Space.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue(Text("Step \(currentIndex + 1) of \(steps.count - 1): \(viewModel.currentStep.title)"))
    }

    private var footer: some View {
        VStack(spacing: Brand.Space.md) {
            HStack(spacing: Brand.Space.md) {
                if viewModel.currentStep.previous != nil {
                    Button {
                        Haptics.lightImpact()
                        viewModel.goBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                            .frame(height: 24)
                    }
                    .secondaryActionButton(tint: .mygraPurple)
                    .frame(maxWidth: 64)
                    .accessibilityLabel("Back")
                    .accessibilityHint("Returns to the previous step.")
                }

                Button {
                    Haptics.mediumImpact()
                    viewModel.advance()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
                .primaryActionButton()
                .keyboardShortcut(.defaultAction)
                .accessibilityHint("Moves to the next onboarding step.")
            }

            if viewModel.currentStep.isSkippable {
                Button {
                    Haptics.lightImpact()
                    viewModel.skip()
                } label: {
                    Text(viewModel.currentStep.isPermissionStep ? "Not now" : "Skip")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .hoverHighlight()
                .accessibilityHint("Skips this step. You can change this later in Settings.")
            }
        }
        .frame(maxWidth: Brand.readableWidth)
        .padding(.horizontal, Brand.Space.xl)
        .padding(.top, Brand.Space.md)
        .padding(.bottom, Brand.Space.xl)
        .frame(maxWidth: .infinity)
        .background(.bar)
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

        func goBack() {
            guard let previous = currentStep.previous else { return }
            currentStep = previous
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
