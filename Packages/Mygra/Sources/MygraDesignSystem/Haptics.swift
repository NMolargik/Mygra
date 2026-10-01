//
//  Haptics.swift
//  MygraDesignSystem
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

public enum Haptics {
    public static var isEnabled: Bool = true

    public static func lightImpact() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func mediumImpact() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func success() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    public static func error() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}
#else
import Foundation

/// No-op stand-in on platforms without UIKit haptics so call sites stay unconditional.
public enum Haptics {
    public static var isEnabled: Bool = true
    public static func lightImpact() {}
    public static func mediumImpact() {}
    public static func success() {}
    public static func error() {}
}
#endif
