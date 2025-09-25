//
//  NoteDetailView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/16/25.
//

import SwiftUI

struct NoteDetailView: View {
    let note: String
    
    var body: some View {
        InfoDetailView(title: "Note") {
            Text(note)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NoteDetailView(note: "This is a note")
}
