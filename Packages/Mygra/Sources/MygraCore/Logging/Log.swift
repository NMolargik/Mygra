//
//  Log.swift
//  MygraCore
//
//  One os.Logger per subsystem category. Never `print` — files calling `Log`
//  need their own `import os` (MemberImportVisibility).
//

import Foundation
import os

nonisolated public enum Log {
    private static let subsystem = "com.molargiksoftware.Mygra"

    public static let app = Logger(subsystem: subsystem, category: "App")
    public static let migraine = Logger(subsystem: subsystem, category: "Migraine")
    public static let health = Logger(subsystem: subsystem, category: "Health")
    public static let weather = Logger(subsystem: subsystem, category: "Weather")
    public static let insights = Logger(subsystem: subsystem, category: "Insights")
    public static let intelligence = Logger(subsystem: subsystem, category: "Intelligence")
    public static let sync = Logger(subsystem: subsystem, category: "CloudSync")
    public static let watch = Logger(subsystem: subsystem, category: "Watch")
    public static let user = Logger(subsystem: subsystem, category: "User")
    public static let widgets = Logger(subsystem: subsystem, category: "Widgets")
    public static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")
    public static let spotlight = Logger(subsystem: subsystem, category: "Spotlight")
    public static let notifications = Logger(subsystem: subsystem, category: "Notifications")
}
