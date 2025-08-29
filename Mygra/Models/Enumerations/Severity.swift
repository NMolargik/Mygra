//
//  Severity.swift
//  Mygra
//
//  Created by Nick Molargik on 8/23/25.
//

import Foundation
import SwiftUI

enum Severity: String, Codable, CaseIterable, Sendable {
    case low, medium, high
    
    public var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    func text(for painLevel: Int) -> String {
        switch self {
        case .low:
            return "Low (\(painLevel))"
        case .medium:
            return "Medium (\(painLevel))"
        case .high:
            return "High (\(painLevel))"
        }
    }
    
    static func from(painLevel: Int) -> Severity {
        switch painLevel {
        case ..<4:   return .low      // 0–3
        case 4...6:  return .medium   // 4–6
        default:     return .high     // 7–10
        }
    }
}
