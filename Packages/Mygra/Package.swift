// swift-tools-version: 6.2
//
//  Package.swift
//  Mygra
//
//  The umbrella package holding the whole app: pure domain (Core), persistence (Data),
//  system-framework services (Services), the design system, one module per feature, and
//  the composition root. The app/widget/watch targets are thin shells over these products.
//  Dependencies point inward — features depend on the design system and core; data
//  implements core's protocols; core depends on nothing but Foundation + SwiftData.
//

import PackageDescription

let isolation: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Mygra",
    defaultLocalization: "en",
    // Match the app targets' floors (iOS 18 / watchOS 10); macOS is the host `swift test` floor.
    platforms: [.iOS("18.0"), .watchOS("10.0"), .macOS("15.0")],
    products: [
        .library(name: "MygraCore", targets: ["MygraCore"]),
        .library(name: "MygraData", targets: ["MygraData"]),
        .library(name: "MygraServices", targets: ["MygraServices"]),
        .library(name: "MygraDesignSystem", targets: ["MygraDesignSystem"]),
        .library(name: "MygraFeatureShared", targets: ["MygraFeatureShared"]),
        .library(name: "MygraFeatureDashboard", targets: ["MygraFeatureDashboard"]),
        .library(name: "MygraFeatureCalendar", targets: ["MygraFeatureCalendar"]),
        .library(name: "MygraFeatureMigraines", targets: ["MygraFeatureMigraines"]),
        .library(name: "MygraFeatureAssistant", targets: ["MygraFeatureAssistant"]),
        .library(name: "MygraFeatureSettings", targets: ["MygraFeatureSettings"]),
        .library(name: "MygraFeatureOnboarding", targets: ["MygraFeatureOnboarding"]),
        .library(name: "MygraComposition", targets: ["MygraComposition"]),
    ],
    targets: [
        .target(
            name: "MygraCore",
            swiftSettings: isolation
        ),
        .target(
            name: "MygraData",
            dependencies: ["MygraCore"],
            swiftSettings: isolation
        ),
        .target(
            name: "MygraServices",
            dependencies: ["MygraCore"],
            swiftSettings: isolation
        ),
        .target(
            name: "MygraDesignSystem",
            dependencies: ["MygraCore"],
            swiftSettings: isolation
        ),
        .target(
            name: "MygraFeatureShared",
            dependencies: ["MygraCore", "MygraDesignSystem", "MygraServices"],
            swiftSettings: isolation
        ),
        .target(
            name: "MygraFeatureCalendar",
            dependencies: ["MygraCore", "MygraDesignSystem", "MygraFeatureShared"],
            swiftSettings: isolation
        ),
        .target(
            name: "MygraFeatureAssistant",
            dependencies: ["MygraCore", "MygraDesignSystem", "MygraFeatureShared"],
            swiftSettings: isolation
        ),
        .target(
            name: "MygraFeatureMigraines",
            dependencies: ["MygraCore", "MygraDesignSystem", "MygraServices", "MygraFeatureShared"],
            swiftSettings: isolation
        ),
        .target(
            name: "MygraFeatureSettings",
            dependencies: ["MygraCore", "MygraDesignSystem", "MygraServices", "MygraFeatureShared"],
            swiftSettings: isolation
        ),
        .target(
            name: "MygraFeatureDashboard",
            dependencies: ["MygraCore", "MygraDesignSystem", "MygraServices", "MygraFeatureShared", "MygraFeatureAssistant"],
            swiftSettings: isolation
        ),
        .target(
            name: "MygraFeatureOnboarding",
            dependencies: ["MygraCore", "MygraDesignSystem", "MygraServices", "MygraFeatureShared", "MygraFeatureSettings"],
            swiftSettings: isolation
        ),
        .target(
            name: "MygraComposition",
            dependencies: [
                "MygraCore", "MygraData", "MygraServices", "MygraDesignSystem", "MygraFeatureShared",
                "MygraFeatureDashboard", "MygraFeatureCalendar", "MygraFeatureMigraines",
                "MygraFeatureAssistant", "MygraFeatureSettings", "MygraFeatureOnboarding",
            ],
            swiftSettings: isolation
        ),
        .testTarget(name: "MygraCoreTests", dependencies: ["MygraCore"], swiftSettings: isolation),
        .testTarget(name: "MygraDataTests", dependencies: ["MygraData"], swiftSettings: isolation),
        .testTarget(name: "MygraServicesTests", dependencies: ["MygraServices"], swiftSettings: isolation),
        .testTarget(name: "MygraFeatureSharedTests", dependencies: ["MygraFeatureShared"], swiftSettings: isolation),
        .testTarget(name: "MygraFeatureDashboardTests", dependencies: ["MygraFeatureDashboard"], swiftSettings: isolation),
        .testTarget(name: "MygraFeatureCalendarTests", dependencies: ["MygraFeatureCalendar"], swiftSettings: isolation),
        .testTarget(name: "MygraFeatureMigrainesTests", dependencies: ["MygraFeatureMigraines"], swiftSettings: isolation),
        .testTarget(name: "MygraFeatureAssistantTests", dependencies: ["MygraFeatureAssistant"], swiftSettings: isolation),
        .testTarget(name: "MygraFeatureSettingsTests", dependencies: ["MygraFeatureSettings"], swiftSettings: isolation),
        .testTarget(name: "MygraFeatureOnboardingTests", dependencies: ["MygraFeatureOnboarding"], swiftSettings: isolation),
        .testTarget(name: "MygraCompositionTests", dependencies: ["MygraComposition"], swiftSettings: isolation),
    ]
)
