//
//  AttackModeView.swift
//  MygraFeatureMigraines
//
//  Logging for a severe migraine: near-black, dim warm text, very large targets, no
//  animation, no images. Shows only the elapsed time, five big intensity steps, the
//  user's usual medications, and End Attack. Everything the normal flow asks (triggers,
//  notes, ...) is deferred until after the attack. The app dims its own UI with a black
//  veil; it never changes system brightness.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

public struct AttackModeView: View {
    @Environment(AttackModeModel.self) private var attack

    /// First tap on End Attack arms it; the second ends. A dark room, a throbbing head,
    /// and a thumb make a stray tap likely.
    @State private var isEndArmed = false

    public init() {}

    public var body: some View {
        ZStack {
            AttackColors.background.ignoresSafeArea()

            if let ongoing = attack.ongoing {
                ScrollView {
                    VStack(spacing: Brand.Space.lg) {
                        topBar
                        elapsed(since: ongoing.startDate)
                        intensitySection
                        medicationSection
                        endButton
                    }
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Brand.Space.lg)
                    .padding(.vertical, Brand.Space.md)
                }
                .scrollIndicators(.hidden)
            }

            // In-app dimming only: a non-interactive black veil over our own UI.
            Color.black
                .opacity(AttackPalette.dimOverlayOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .transaction { $0.animation = nil }
        .animation(nil, value: isEndArmed)
        .task(id: isEndArmed) {
            guard isEndArmed else { return }
            try? await Task.sleep(for: .seconds(4))
            isEndArmed = false
        }
        .accessibilityIdentifier("attackModeScreen")
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack {
            Button {
                Haptics.lightImpact()
                attack.close()
            } label: {
                Text("Close")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, Brand.Space.xl)
            }
            .buttonStyle(AttackBlockButtonStyle(minHeight: 56))
            .fixedSize()
            .accessibilityIdentifier("attackCloseButton")
            Spacer()
        }
    }

    private func elapsed(since start: Date) -> some View {
        VStack(spacing: Brand.Space.xs) {
            Text("Attack in progress")
                .font(.title3.weight(.medium))
                .foregroundStyle(AttackColors.secondaryText)
            TimelineView(.periodic(from: .now, by: 20)) { context in
                Text(MigraineDates.compactDurationString(context.date.timeIntervalSince(start)))
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AttackColors.primaryText)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .accessibilityIdentifier("attackElapsed")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Brand.Space.sm)
        .accessibilityElement(children: .combine)
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            HStack {
                Text("Pain now")
                Spacer()
                if let level = attack.selectedLevel {
                    Text(AttackIntensity.label(for: level))
                }
            }
            .font(.title3.weight(.medium))
            .foregroundStyle(AttackColors.secondaryText)

            HStack(spacing: Brand.Space.sm) {
                ForEach(AttackIntensity.levels, id: \.self) { level in
                    Button {
                        Haptics.lightImpact()
                        attack.setIntensity(level)
                    } label: {
                        Text("\(level)")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .buttonStyle(AttackBlockButtonStyle(isSelected: attack.selectedLevel == level, minHeight: 96))
                    .accessibilityLabel(Text("Pain \(level) of 10"))
                    .accessibilityAddTraits(attack.selectedLevel == level ? .isSelected : [])
                    .accessibilityIdentifier("attackIntensity\(level)")
                }
            }
        }
    }

    private var medicationSection: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            Text("Took medication")
                .font(.title3.weight(.medium))
                .foregroundStyle(AttackColors.secondaryText)

            ForEach(attack.quickMedications) { medication in
                Button {
                    Haptics.lightImpact()
                    attack.logMedication(medication)
                } label: {
                    Text(medication.label)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Brand.Space.lg)
                        .padding(.vertical, Brand.Space.sm)
                }
                .buttonStyle(AttackBlockButtonStyle(minHeight: 72))
                .accessibilityLabel(Text("Log \(medication.label)"))
                .accessibilityIdentifier("attackMedication")
            }

            if let last = attack.lastLoggedMedication {
                Text("Logged \(last.medication.label) at \(DateFormatting.time(last.date))")
                    .font(.callout)
                    .foregroundStyle(AttackColors.secondaryText)
                    .accessibilityIdentifier("attackLastMedication")
            }
        }
    }

    private var endButton: some View {
        Button {
            Haptics.lightImpact()
            if isEndArmed {
                isEndArmed = false
                attack.endAttack()
            } else {
                isEndArmed = true
            }
        } label: {
            Text(isEndArmed ? "Tap again to end" : "End Attack")
                .font(.title2.weight(.semibold))
        }
        .buttonStyle(AttackBlockButtonStyle(isDestructive: true, minHeight: 88))
        .padding(.top, Brand.Space.md)
        .accessibilityIdentifier("attackEndButton")
    }
}

#if DEBUG
#Preview("Attack Mode") {
    let env = PreviewEnvironment()
    return AttackModeView()
        .previewEnvironment(env)
}
#endif
#endif
