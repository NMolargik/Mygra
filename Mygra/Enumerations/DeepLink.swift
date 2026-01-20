//
//  DeepLink.swift
//  Mygra
//
//  Created by Nick Molargik on 1/20/26.
//

import Foundation

/// Deep link actions that can be triggered from widgets or external URLs
enum DeepLink: Equatable {
    case newMigraine
    case home
    case list
    case settings
}
