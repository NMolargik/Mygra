//
//  ToastStyle.swift
//  Mygra
//
//  Visual style for lightweight top-of-screen toasts.
//

import SwiftUI

enum ToastStyle {
    case error
    case success
    case info

    var tint: Color {
        switch self {
        case .error: .red
        case .success: .green
        case .info: .mygraBlue
        }
    }

    var iconName: String {
        switch self {
        case .error: "exclamationmark.circle.fill"
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        }
    }
}
