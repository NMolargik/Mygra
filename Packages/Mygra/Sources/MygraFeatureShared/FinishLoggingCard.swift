//
//  FinishLoggingCard.swift
//  MygraFeatureShared
//
//  The in-app half of the deferred prompt: after End Attack, a calm card on the
//  dashboard offers to open the migraine's detail flow so triggers and notes can be added
//  once the attack has passed. "Not now" forgets it (and its notification).
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

public struct FinishLoggingCard: View {
    @Environment(AttackModeModel.self) private var attack
    @Environment(AppRouter.self) private var router

    public init() {}

    public var body: some View {
        if let item = attack.pendingFinish.last {
            VStack(alignment: .leading, spacing: Brand.Space.md) {
                VStack(alignment: .leading, spacing: Brand.Space.xs) {
                    Text("Finish logging your migraine")
                        .font(.headline)
                    Text("Your attack from \(item.endedAt.formatted(date: .abbreviated, time: .shortened)) is saved. Add triggers and notes whenever you feel up to it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: Brand.Space.sm) {
                    Button {
                        Haptics.lightImpact()
                        router.open(.finishLogging(item.id))
                    } label: {
                        Text("Finish Logging").frame(maxWidth: .infinity)
                    }
                    .primaryActionButton()
                    .accessibilityIdentifier("finishLoggingButton")

                    Button {
                        Haptics.lightImpact()
                        attack.resolveFinish(item.id)
                    } label: {
                        Text("Not now")
                    }
                    .secondaryActionButton()
                    .accessibilityIdentifier("finishLoggingDismissButton")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Brand.Space.lg)
            .cardSurface()
            .accessibilityIdentifier("finishLoggingCard")
        }
    }
}
#endif
