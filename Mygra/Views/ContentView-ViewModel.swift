//
//  ContentView-ViewModel.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI
import Observation

extension ContentView {
    @Observable
    class ViewModel {
        var appStage: AppStage = .start

        var pendingDeepLinkID: UUID? = nil
        var pendingDeepLinkAction: String? = nil
        
        var leadingTransition: AnyTransition {
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        }

        func handleOpenURL(_ url: URL) -> Bool {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
            guard components.host?.lowercased() == "migraine" else { return false }
            
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let id = UUID(uuidString: path) else { return false }
            let action = components.queryItems?.first(where: { $0.name.lowercased() == "action" })?.value
            
            // Set pending states so MainView can process them after transition/mount.
            self.pendingDeepLinkID = id
            self.pendingDeepLinkAction = action
            
            // If we’re not in main, signal the caller to navigate there.
            return self.appStage != .main
        }
    }
}

