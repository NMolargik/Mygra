//
//  MigraineAssistantView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI
import Combine

struct MigraineAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(InsightManager.self) private var insightManager: InsightManager

    @State private var inputText: String = ""
    @State private var lastMessageID: AnyHashable? = nil
    @State private var keyboardHeight: CGFloat = 0

    // Haptics state
    @State private var isSending: Bool = false
    @State private var lastConversationCount: Int = 0

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        header

                        Divider().padding(.horizontal)

                        let messages = insightManager.intelligenceManager.conversation
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, msg in
                            if msg.role != .system {
                                ChatBubble(message: msg)
                                    .id(messageID(for: index, msg: msg))
                                    .padding(.horizontal, 12)
                                    .onAppear {
                                        // Track last visible message id
                                        lastMessageID = messageID(for: index, msg: msg)
                                    }
                            }
                        }

                        if insightManager.isGeneratingGuidance {
                            HStack {
                                TypingIndicator()
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color(uiColor: .secondarySystemBackground))
                                    )
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .transition(.opacity)
                        }

                        // Small spacer so last bubble isn’t glued to the input bar
                        Color.clear.frame(height: 8)
                    }
                    .padding(.top, 8)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    lightTap()
                    dismissKeyboard()
                }
                .onChange(of: insightManager.intelligenceManager.conversation) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: insightManager.isGeneratingGuidance) { old, new in
                    scrollToBottom(proxy: proxy)
                    // When generation completes, decide success/error haptic based on conversation change
                    if old == true && new == false {
                        let conv = insightManager.intelligenceManager.conversation.filter { $0.role != .system }
                        if conv.count > lastConversationCount {
                            // New message arrived
                            if let last = conv.last, last.role == .assistant {
                                // If it’s the generic error message, treat as error
                                if last.content == "Sorry, I ran into a problem." {
                                    errorTap()
                                } else {
                                    successTap()
                                }
                            }
                        }
                        isSending = false
                        lastConversationCount = conv.count
                    }
                }
                .onChange(of: keyboardHeight) { _, _ in
                    // Nudge to bottom when keyboard shows/hides
                    withAnimation(.easeOut(duration: 0.2)) {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onAppear {
                    // Initialize conversation count
                    lastConversationCount = insightManager.intelligenceManager.conversation.filter { $0.role != .system }.count
                    // Start a chat if not active
                    if !insightManager.intelligenceManager.isChatActive {
                        Task { await insightManager.startCounselorChat() }
                    }
                    // Initial scroll to bottom shortly after appear
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
            }
            // Input bar pinned to the safe area bottom (stays above the keyboard)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                inputBar
                    .background(.ultraThinMaterial)
                    .overlay(Divider(), alignment: .top)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        lightTap()
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .keyboard) {
                    Button {
                        lightTap()
                        dismissKeyboard()
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                }
            }
            .onReceive(KeyboardObserver.shared.publisher) { height in
                // Keep for gentle auto-scroll; no layout padding based on this
                self.keyboardHeight = height
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 8) {
            Text("Migraine Assistant")
                .font(.title2).bold()
            Text("Powered by Apple Intelligence")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .id("assistantHeader")
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(insightManager.isGeneratingGuidance)
                .submitLabel(.send)
                .onSubmit {
                    lightTap()
                    send()
                }

            Button {
                lightTap()
                send()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || insightManager.isGeneratingGuidance)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !insightManager.isGeneratingGuidance else { return }
        inputText = ""
        isSending = true
        Task {
            _ = await insightManager.sendCounselorMessage(text)
            // Completion haptics handled by isGeneratingGuidance change observer
        }
    }

    private func messageID(for index: Int, msg: ChatMessage) -> AnyHashable {
        // Prefer content hash but include index to avoid collisions across identical messages
        return "\(index)-\(msg.role.rawValue)-\(msg.content.hashValue)"
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        let id: AnyHashable = lastMessageID ?? AnyHashable("assistantHeader")
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }

    // MARK: - Keyboard dismissal
    private func dismissKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    // MARK: - Haptics

    private func lightTap() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        #endif
    }

    private func successTap() {
        #if os(iOS)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif
    }

    private func errorTap() {
        #if os(iOS)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.error)
        #endif
    }
}

// MARK: - ChatBubble

private struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isUser ? Color.accentColor.opacity(0.18) : Color(uiColor: .secondarySystemBackground))
                )
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - TypingIndicator

private struct TypingIndicator: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(opacity(for: i))
            }
        }
        .accessibilityLabel("Assistant is typing")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func opacity(for index: Int) -> Double {
        let base = (Double(index) * 0.3)
        let t = (sin((phase * 2 * .pi) + base) + 1) / 2
        return 0.35 + t * 0.65
    }
}

// MARK: - Keyboard observer

private final class KeyboardObserver {
    static let shared = KeyboardObserver()

    private let subject = PassthroughSubject<CGFloat, Never>()
    var publisher: AnyPublisher<CGFloat, Never> { subject.eraseToAnyPublisher() }

    private var willShow: Any?
    private var willHide: Any?
    private var willChangeFrame: Any?

    private init() {
        #if os(iOS)
        willShow = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] note in
            self?.handle(note: note)
        }
        willHide = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
            self?.subject.send(0)
        }
        willChangeFrame = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] note in
            self?.handle(note: note)
        }
        #endif
    }

    deinit {
        if let willShow { NotificationCenter.default.removeObserver(willShow) }
        if let willHide { NotificationCenter.default.removeObserver(willHide) }
        if let willChangeFrame { NotificationCenter.default.removeObserver(willChangeFrame) }
    }

    private func handle(note: Notification) {
        #if os(iOS)
        guard
            let info = note.userInfo,
            let frameValue = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        else { return }

        // Determine the most relevant window from the notification context.
        // keyboard notifications are posted by the system with an object that is often a UIResponder/UIView/Window.
        let window: UIWindow? = {
            if let w = note.object as? UIWindow {
                return w
            }
            if let view = note.object as? UIView {
                return view.window
            }
            if let responder = note.object as? UIResponder {
                // Walk the responder chain to find a window, if possible
                var current: UIResponder? = responder
                while let r = current {
                    if let v = r as? UIView, let w = v.window { return w }
                    if let w = r as? UIWindow { return w }
                    current = r.next
                }
            }
            // Fallback: use keyWindow if available (multi-scene aware on iOS 13+)
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        }()

        guard let win = window else {
            // If no window context, fall back to sending zero change rather than using UIScreen.main
            subject.send(0)
            return
        }

        // Convert keyboard frame into the window’s coordinate space and compute overlap with window bounds.
        let keyboardEndInWindow = win.convert(frameValue.cgRectValue, from: nil)
        let overlap = win.bounds.intersection(keyboardEndInWindow)
        let height = max(0, overlap.height)

        subject.send(height)
        #endif
    }
}

#Preview {
    MigraineAssistantView()
}

