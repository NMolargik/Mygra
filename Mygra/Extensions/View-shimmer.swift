//
//  View-shimmer.swift
//  Mygra
//
//  Created by Nick Molargik on 9/14/25.
//

import SwiftUI

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}
