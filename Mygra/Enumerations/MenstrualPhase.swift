//
//  MenstrualPhase.swift
//  Mygra
//
//  Created by Nick Molargik on 8/22/25.
//

import Foundation

enum MenstrualPhase: String, Codable, CaseIterable, Hashable {
    case follicular
    case ovulatory
    case luteal
    case menstrual
}
