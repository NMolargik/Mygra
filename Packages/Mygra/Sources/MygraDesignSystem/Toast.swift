//
//  Toast.swift
//  MygraDesignSystem
//
//  Lightweight top-of-screen toasts: style, item, manager, rendering, and the
//  `.toastContainer()` overlay (background iCloud sync status, persistence errors, and
//  general feedback instead of blocking screens).
//

import SwiftUI

// MARK: - Toast Style

public enum ToastStyle: Sendable {
    case error
    case success
    case info

    public var tint: Color {
        switch self {
        case .error: .red
        case .success: .green
        case .info: .mygraBlue
        }
    }

    public var iconName: String {
        switch self {
        case .error: "exclamationmark.circle.fill"
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        }
    }
}

// MARK: - Toast Item

public struct ToastItem: Identifiable, Equatable {
    public let id = UUID()
    public let message: String
    public let style: ToastStyle
    public let icon: String?
    public let duration: TimeInterval

    public init(message: String, style: ToastStyle = .info, icon: String? = nil, duration: TimeInterval = 3.0) {
        self.message = message
        self.style = style
        self.icon = icon
        self.duration = duration
    }

    public static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Manager

@MainActor
@Observable
public final class ToastManager {
    public private(set) var currentToast: ToastItem?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    public init() {}

    public func show(_ toast: ToastItem) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentToast = toast
        }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(toast.duration))
            if !Task.isCancelled {
                self?.dismiss()
            }
        }
    }

    public func show(message: String, style: ToastStyle = .info, icon: String? = nil) {
        show(ToastItem(message: message, style: style, icon: icon))
    }

    public func showSuccess(_ message: String) {
        show(ToastItem(message: message, style: .success))
    }

    public func show(error: any Error) {
        let message = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        show(ToastItem(message: message, style: .error))
    }

    public func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentToast = nil
        }
    }
}

#if os(iOS)

// MARK: - Toast View

public struct ToastView: View {
    let toast: ToastItem
    let onDismiss: () -> Void

    public init(toast: ToastItem, onDismiss: @escaping () -> Void) {
        self.toast = toast
        self.onDismiss = onDismiss
    }

    public var body: some View {
        toastContent
            .padding(.horizontal, Brand.Space.lg)
            .frame(maxWidth: 360)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
    }

    @ContentBuilder
    private var toastContent: some View {
        if #available(iOS 26.0, *) {
            toastBody
                .padding(.horizontal, Brand.Space.lg)
                .padding(.vertical, Brand.Space.md)
                .glassEffect(.regular.tint(toast.style.tint.opacity(0.65)).interactive())
        } else {
            toastBody
                .padding(.horizontal, Brand.Space.lg)
                .padding(.vertical, Brand.Space.md)
                .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                .overlay(Capsule(style: .continuous).strokeBorder(.quaternary))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
    }

    private var toastBody: some View {
        HStack(spacing: Brand.Space.md) {
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

public struct ToastContainerModifier: ViewModifier {
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init() {}

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: horizontalSizeClass == .regular ? .topLeading : .top) {
                if let toast = toastManager.currentToast {
                    ToastView(toast: toast) {
                        toastManager.dismiss()
                    }
                    .id(toast.id)
                    .padding(.top, Brand.Space.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }
            }
    }
}

extension View {
    public func toastContainer() -> some View {
        modifier(ToastContainerModifier())
    }
}

#Preview("Toast Styles") {
    struct PreviewContainer: View {
        @State private var toastManager = ToastManager()

        var body: some View {
            VStack(spacing: 20) {
                Button("Show Success") { toastManager.showSuccess("Migraine saved") }
                Button("Show Info") { toastManager.show(message: "Syncing with iCloud…", style: .info, icon: "icloud.fill") }
                Button("Show Error") { toastManager.show(message: "Something went wrong", style: .error) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toastContainer()
            .environment(toastManager)
        }
    }
    return PreviewContainer()
}
#endif
