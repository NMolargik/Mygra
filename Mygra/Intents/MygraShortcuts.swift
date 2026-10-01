//
//  MygraShortcuts.swift
//  Mygra
//
//  Registers App Shortcuts so the custom intents are discoverable in Spotlight, Siri,
//  and the Shortcuts app without any user setup.
//

import AppIntents

struct MygraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartMigraineIntent(),
            phrases: [
                "Start tracking a migraine in \(.applicationName)",
                "Log a new migraine in \(.applicationName)",
                "I have a migraine, \(.applicationName)",
            ],
            shortTitle: "Start Migraine",
            systemImageName: "bolt.heart"
        )
        AppShortcut(
            intent: EndMigraineIntent(),
            phrases: [
                "End my migraine in \(.applicationName)",
                "My migraine is over in \(.applicationName)",
                "Stop tracking my migraine in \(.applicationName)",
            ],
            shortTitle: "End Migraine",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: DaysSinceLastMigraineIntent(),
            phrases: [
                "How long since my last migraine in \(.applicationName)",
                "When was my last migraine in \(.applicationName)",
                "Days since my last migraine in \(.applicationName)",
            ],
            shortTitle: "Days Since Last Migraine",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: GetMigraineStatusIntent(),
            phrases: [
                "Am I having a migraine in \(.applicationName)",
                "Check my migraine status in \(.applicationName)",
                "How long has my migraine lasted in \(.applicationName)",
            ],
            shortTitle: "Migraine Status",
            systemImageName: "waveform.path.ecg"
        )
        AppShortcut(
            intent: UpdateMigraineIntensityIntent(),
            phrases: [
                "Update my migraine in \(.applicationName)",
                "Log my pain level in \(.applicationName)",
            ],
            shortTitle: "Update Intensity",
            systemImageName: "slider.horizontal.3"
        )
        AppShortcut(
            intent: LogMigraineIntent(),
            phrases: [
                "Log a migraine with \(.applicationName)",
                "Open \(.applicationName) to log a migraine",
            ],
            shortTitle: "Log a Migraine",
            systemImageName: "plus.circle"
        )
    }
}
