//
//  SplashView.swift
//  MygraComposition
//
//  First launch: the wordmark, tagline, and the Mygra head easing in over the brand
//  wash, then one prominent call to action.
//

#if os(iOS)
import SwiftUI
import MygraDesignSystem

struct SplashView: View {
    let onContinue: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var buttonVisible = false

    private var isRegular: Bool { horizontalSizeClass == .regular }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Mygra")
                .font(.system(size: isRegular ? 90 : 60, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient.mygraHorizontal)
                .opacity(titleVisible ? 1 : 0)
                .scaleEffect(titleVisible ? 1 : 0.8)
                .padding(.bottom, Brand.Space.xs)
                .accessibilityAddTraits(.isHeader)

            Text("Your Intelligent Migraine Journal")
                .font(isRegular ? .title : .title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(subtitleVisible ? 1 : 0)
                .offset(y: subtitleVisible ? 0 : 20)

            Image("mygra_head")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: isRegular ? 240 : 220)
                .opacity(subtitleVisible ? 1 : 0)
                .scaleEffect(subtitleVisible ? 1 : 0.6)
                .padding(.vertical, Brand.Space.xl)
                .accessibilityLabel("Mygra app logo")

            Spacer()

            Button {
                Haptics.lightImpact()
                onContinue()
            } label: {
                Label("Get Started", systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Brand.Space.xs)
            }
            .primaryActionButton()
            .opacity(buttonVisible ? 1 : 0)
            .scaleEffect(buttonVisible ? 1 : 0.96)
            .accessibilityHint("Begins onboarding")
            .padding(.bottom, Brand.Space.xxl)
        }
        .padding(.horizontal, Brand.Space.xl)
        .frame(maxWidth: isRegular ? 560 : .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient.mygraWash.ignoresSafeArea())
        .onAppear(perform: reveal)
    }

    private func reveal() {
        if reduceMotion {
            titleVisible = true
            subtitleVisible = true
            buttonVisible = true
            return
        }
        withAnimation(.easeOut(duration: 0.6)) { titleVisible = true }
        withAnimation(.bouncy(duration: 0.7).delay(0.35)) { subtitleVisible = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.9)) { buttonVisible = true }
    }
}

#if DEBUG
#Preview {
    SplashView(onContinue: {})
}
#endif
#endif
