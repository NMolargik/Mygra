//
//  String+csvEscaped.swift
//  Mygra
//
//  Created by Nick Molargik on 8/3/25.
//

import Foundation

extension String {
    var csvEscaped: String {
        let escaped = replacingOccurrences(of: "\"", with: "\"\"")
        return contains(",") || contains("\n") || contains("\"") ? "\"\(escaped)\"" : self
    }
}
