//
//  ToastView.swift
//  Mygra
//
//  Top-of-screen toast rendering for ToastManager.
//

import SwiftUI

struct ToastView: View {
    let toast: ToastItem
    let onDismiss: () -> Void

    var body: some View {
        toastContent
            .padding(.horizontal, 16)
            .frame(maxWidth: 360)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
    }

    @ContentBuilder
    private var toastContent: some View {
        if #available(iOS 26.0, *) {
            toastBody
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular.tint(toast.style.tint.opacity(0.65)).interactive())
        } else {
            toastBody
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(Capsule(style: .continuous).strokeBorder(.quaternary))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
    }

    private var toastBody: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.icon ?? toast.style.iconName)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(toast.style.tint)
                .accessibilityHidden(true)

            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Button {
                Haptics.lightImpact()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Circle().fill(.quaternary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Dismiss"))
        }
    }
}

// MARK: - Toast Container Modifier

struct ToastContainerModifier: ViewModifier {
    @Environment(ToastManager.self) private var toastManager

    /// iPad anchors toasts to the top-leading corner so they don't crowd
    /// the split-view title area.
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: isIPad ? .topLeading : .top) {
                if let toast = toastManager.currentToast {
                    ToastView(toast: toast) {
                        toastManager.dismiss()
                    }
                    .id(toast.id)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }
            }
    }
}

extension View {
    func toastContainer() -> some View {
        modifier(ToastContainerModifier())
    }
}

#Preview("Toast Styles") {
    struct PreviewContainer: View {
        @State private var toastManager = ToastManager()

        var body: some View {
            VStack(spacing: 20) {
                Button("Show Success") { toastManager.showSuccess("Migraine saved") }
                Button("Show Info") {
                    toastManager.show(message: "Syncing with iCloud…", style: .info, icon: "icloud.fill")
                }
                Button("Show Error") { toastManager.show(message: "Something went wrong", style: .error) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toastContainer()
            .environment(toastManager)
        }
    }
    return PreviewContainer()
}
