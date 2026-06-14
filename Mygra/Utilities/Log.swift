//
//  Log.swift
//  Mygra
//
//  Per-category loggers. Use these instead of print() everywhere outside
//  of previews.
//

import Foundation
import os

enum Log {
    private static let subsystem = "com.molargiksoftware.Mygra"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let migraine = Logger(subsystem: subsystem, category: "migraine")
    static let health = Logger(subsystem: subsystem, category: "health")
    static let weather = Logger(subsystem: subsystem, category: "weather")
    static let insights = Logger(subsystem: subsystem, category: "insights")
    static let intelligence = Logger(subsystem: subsystem, category: "intelligence")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let watch = Logger(subsystem: subsystem, category: "watch")
    static let user = Logger(subsystem: subsystem, category: "user")
    static let widgets = Logger(subsystem: subsystem, category: "widgets")
}
