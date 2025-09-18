//
//  File.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import Foundation

extension MigraineActivityAttributes.ContentState {
    static var sample: MigraineActivityAttributes.ContentState {
        .init(migraineID: UUID(), startDate: Date().addingTimeInterval(-3600), severity: 7, notes: "Triggered by stress")
    }
}
