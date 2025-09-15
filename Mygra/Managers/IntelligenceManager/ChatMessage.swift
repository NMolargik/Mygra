//
//  ChatMessage.swift
//  Mygra
//
//  Created by Nick Molargik on 9/14/25.
//

import Foundation

struct ChatMessage: Hashable {
    let role: ChatRole
    let content: String

    static func system(_ text: String) -> ChatMessage { .init(role: .system, content: text) }
    static func user(_ text: String) -> ChatMessage { .init(role: .user, content: text) }
    static func assistant(_ text: String) -> ChatMessage { .init(role: .assistant, content: text) }
}
