//
//  UnitConversion.swift
//  Mygra
//
//  Created by Nick Molargik on 1/12/26.
//

import Foundation

/// Centralized unit conversion constants used throughout the app.
nonisolated enum UnitConversion {
    /// Liters to US fluid ounces (1 L = 33.814 fl oz)
    static let litersToFluidOunces: Double = 33.814

    /// Kilocalories to kilojoules (1 kcal = 4.184 kJ)
    static let kilocaloriesToKilojoules: Double = 4.184

    /// mg/dL to mmol/L for glucose (divide mg/dL by 18.0)
    static let glucoseMgDlToMmolL: Double = 18.0
}
