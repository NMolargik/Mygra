//
//  MigraineAssistantView.swift
//  MygraFeatureAssistant
//
//  The Apple Intelligence analyst chat over `InsightModel`.
//

#if os(iOS)
import SwiftUI
import MygraCore
import MygraDesignSystem
import MygraFeatureShared

public struct MigraineAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(InsightModel.self) private var insights

    @State private var inputText = ""
    @State private var lastMessageID: String?
    @State private var lastConversationCount = 0

    public init() {}

    private var isBusy: Bool { insights.isSending || insights.isGeneratingGuidance }

    private var sendEnabled: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
    }

    private var visibleMessages: [ChatMessage] {
        insights.conversation.filter { $0.role != .system }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.mygraWash
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            VStack(spacing: 8) {
                                Text("Migraine Assistant")
                                    .font(.title2).bold()
                                AppleIntelligenceBadge(isGenerating: isBusy)
                            }
                            .id("assistantHeader")

                            Divider().padding(.horizontal)

                            ForEach(Array(visibleMessages.enumerated()), id: \.offset) { index, message in
                                ChatBubble(message: message)
                                    .id(messageID(for: index, message: message))
                                    .padding(.horizontal, 12)
                                    .onAppear { lastMessageID = messageID(for: index, message: message) }
                            }

                            if isBusy {
                                HStack {
                                    TypingIndicator()
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(secondaryBackground))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .transition(.opacity)
                            }

                            Color.clear.frame(height: 8)
                        }
                        .padding(.top, 8)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { Haptics.lightImpact() }
                    .onChange(of: insights.conversation) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: isBusy) { wasBusy, nowBusy in
                        scrollToBottom(proxy: proxy)
                        guard wasBusy, !nowBusy else { return }
                        let messages = visibleMessages
                        if messages.count > lastConversationCount, let last = messages.last, last.role == .assistant {
                            if last.content == InsightModel.chatFailureReply {
                                Haptics.error()
                            } else {
                                Haptics.success()
                            }
                        }
                        lastConversationCount = messages.count
                    }
                    .onAppear {
                        lastConversationCount = visibleMessages.count
                        if !insights.isChatActive {
                            Task { await insights.startChat() }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    inputBar
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            Haptics.lightImpact()
                            dismiss()
                        } label: {
                            Label("Close", systemImage: "xmark")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $inputText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .lineLimit(1)
                .disabled(isBusy)
                .submitLabel(.send)
                .onChange(of: inputText) { _, newValue in
                    if newValue.contains(where: \.isNewline) {
                        inputText = newValue.filter { !$0.isNewline }
                    }
                }
                .onSubmit {
                    Haptics.lightImpact()
                    send()
                }

            Button {
                Haptics.lightImpact()
                send()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .symbolEffect(.wiggle, value: sendEnabled)
                    .foregroundStyle(.white.gradient)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(sendEnabled ? Color.mygraBlue : Color.secondary.opacity(0.25)))
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: sendEnabled)
            .accessibilityLabel("Send")
            .disabled(!sendEnabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(.regularMaterial))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isBusy else { return }
        inputText = ""
        Task { await insights.send(text) }
    }

    private func messageID(for index: Int, message: ChatMessage) -> String {
        "\(index)-\(message.role.rawValue)-\(message.content.hashValue)"
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(lastMessageID ?? "assistantHeader", anchor: .bottom)
        }
    }
}

#Preview("Migraine Assistant") {
    MigraineAssistantView()
        .previewEnvironment()
}
#endif
