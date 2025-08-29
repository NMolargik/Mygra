//
//  DummyUserManager.swift
//  Mygra
//
//  Created by Nick Molargik on 8/28/25.
//

import Foundation
import SwiftData

class DummyUserManager: UserManager {
    init() {
        // Provide a throwaway ModelContext using an in-memory container
        let container = try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        super.init(context: container.mainContext)
    }
}
