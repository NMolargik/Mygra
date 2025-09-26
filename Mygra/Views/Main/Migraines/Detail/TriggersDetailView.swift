//
//  TriggersDetailView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import SwiftUI

struct TriggersDetailView: View {
    let triggers: [MigraineTrigger]
    let customTriggers: [String]
    
    var body: some View {
        InfoDetailView(title: "Triggers") {
            VStack(alignment: .leading, spacing: 8) {
                if !triggers.isEmpty {
                    ForEach(triggers, id: \.self) { t in
                        Label(t.displayName, systemImage: "minus")
                    }
                }
                if !customTriggers.isEmpty {
                    ForEach(customTriggers, id: \.self) { t in
                        Label(t, systemImage: "minus")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    TriggersDetailView(triggers: [], customTriggers: [])
}
