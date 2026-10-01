//
//  ChatBubble.swift
//  MygraFeatureAssistant
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isUser ? Color.mygraBlue.opacity(0.4) : secondaryBackground)
                )
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .accessibilityAddTraits(.isStaticText)
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

#if DEBUG
#Preview {
    VStack {
        ChatBubble(message: .assistant("Hey, how are things going?"))
        ChatBubble(message: .user("Pretty good, thanks."))
    }
    .padding()
}
#endif
#endif
