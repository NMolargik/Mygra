//
//  ToastManager.swift
//  Mygra
//
//  Lightweight top-of-screen toasts used for background iCloud sync status
//  (and other transient messages) instead of a blocking screen. Rendering
//  lives in Views/Components/ToastView.swift.
//

import SwiftUI

// MARK: - Toast Item

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: ToastStyle
    let icon: String?
    let duration: TimeInterval

    init(message: String, style: ToastStyle = .info, icon: String? = nil, duration: TimeInterval = 3.0) {
        self.message = message
        self.style = style
        self.icon = icon
        self.duration = duration
    }

    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Manager

@MainActor
@Observable
final class ToastManager {
    private(set) var currentToast: ToastItem?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    func show(_ toast: ToastItem) {
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

    func show(message: String, style: ToastStyle = .info, icon: String? = nil) {
        show(ToastItem(message: message, style: style, icon: icon))
    }

    func showSuccess(_ message: String) {
        show(ToastItem(message: message, style: .success))
    }

    func show(error: any LocalizedError) {
        show(ToastItem(message: error.errorDescription ?? String(localized: "An error occurred"), style: .error))
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentToast = nil
        }
    }
}
