//
//  SettingsDestination.swift
//  MygraFeatureSettings
//
//  Screens pushed inside the Settings tab. The composition root registers the
//  `navigationDestination` so deep links (`mygra://tags`) can land here too.
//

import Foundation

nonisolated public enum SettingsDestination: Hashable, Sendable {
    case tags
    case dashboardStats
}
