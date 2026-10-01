//
//  SplashView.swift
//  MygraComposition
//

#if os(iOS)
import SwiftUI
import MygraDesignSystem

struct SplashView: View {
    let onContinue: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var buttonVisible = false

    private var isRegular: Bool { horizontalSizeClass == .regular }

    var body: some View {
        VStack {
            Spacer()

            Text("Mygra")
                .font(.system(size: isRegular ? 90 : 60))
                .bold()
                .opacity(titleVisible ? 1 : 0)
                .scaleEffect(titleVisible ? 1 : 0.7)
                .animation(.easeOut(duration: 0.6), value: titleVisible)
                .padding(.bottom, 5)
                .accessibilityAddTraits(.isHeader)

            Text("Your Intelligent Migraine Journal")
                .font(isRegular ? .title : .title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .opacity(subtitleVisible ? 1 : 0)
                .offset(y: subtitleVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.8), value: subtitleVisible)

            Image("mygra_head")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: isRegular ? 200 : 220)
                .opacity(subtitleVisible ? 1 : 0)
                .scaleEffect(subtitleVisible ? 1 : 0)
                .animation(.bouncy(duration: 0.6).delay(0.8), value: subtitleVisible)
                .padding()
                .accessibilityLabel("Mygra app logo")

            Spacer()

            Button {
                Haptics.lightImpact()
                onContinue()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Get Started")
                        .bold()
                }
                .padding()
                .frame(maxWidth: 250)
                .background(Color.mygraPurple)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .opacity(buttonVisible ? 1 : 0)
            .scaleEffect(buttonVisible ? 1 : 0.98)
            .animation(.easeOut(duration: 0.5).delay(1.2), value: buttonVisible)
            .accessibilityHint("Tap to begin using Mygra")

            Spacer()
        }
        .onAppear {
            withAnimation { titleVisible = true }
            withAnimation(.easeOut.delay(0.18)) { subtitleVisible = true }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) { buttonVisible = true }
        }
        .padding(.top, isRegular ? 40 : 80)
        .frame(maxWidth: isRegular ? 520 : .infinity)
        .padding(.horizontal, 24)
    }
}

#Preview {
    SplashView(onContinue: {})
}
#endif
