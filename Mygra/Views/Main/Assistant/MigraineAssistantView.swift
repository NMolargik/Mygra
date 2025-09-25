//
//  MigraineAssistantView.swift
//  Mygra
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI
import Combine
import SwiftData

@available(iOS 26.0, *)
struct MigraineAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(InsightManager.self) private var insightManager: InsightManager

    @State private var inputText: String = ""
    @State private var lastMessageID: AnyHashable? = nil
    @State private var isSending: Bool = false
    @State private var lastConversationCount: Int = 0
    
    private var sendEnabled: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !insightManager.isGeneratingGuidance
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.25), Color.black.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
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
                        Haptics.lightImpact()
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
                                        Haptics.error()
                                    } else {
                                        Haptics.success()
                                    }
                                }
                            }
                            isSending = false
                            lastConversationCount = conv.count
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
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack {
                        HStack(spacing: 8) {
                            TextField("Message", text: $inputText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .lineLimit(1...4)
                                .disabled(insightManager.isGeneratingGuidance)
                                .submitLabel(.send)
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
                                    .symbolVariant(.fill)
                                    .foregroundStyle(.white.gradient)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        Circle()
                                            .fill(sendEnabled ? Color.blue : Color.secondary.opacity(0.25))
                                    )
                            }
                            .buttonStyle(.plain)
                            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: sendEnabled)
                            .accessibilityLabel("Send")
                            .disabled(!sendEnabled)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.thinMaterial)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay(Divider(), alignment: .top)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
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
    
    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !insightManager.isGeneratingGuidance else { return }
        inputText = ""
        isSending = true
        Task {
            _ = await insightManager.sendCounselorMessage(text)
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
}

#Preview("Migraine Assistant") {
    return Group {
        if #available(iOS 26.0, *) {
            let container: ModelContainer = {
                do {
                    return try ModelContainer(
                        for: User.self, Migraine.self, WeatherData.self, HealthData.self,
                        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                    )
                } catch {
                    fatalError("Preview ModelContainer setup failed: \(error)")
                }
            }()

            let previewHealthManager = HealthManager()
            let previewWeatherManager = WeatherManager()
            let previewUserManager = UserManager(context: container.mainContext)
            let previewMigraineManager = MigraineManager(context: container.mainContext, healthManager: previewHealthManager)
            let previewInsightManager = InsightManager(
                userManager: previewUserManager,
                migraineManager: previewMigraineManager,
                weatherManager: previewWeatherManager,
                healthManager: previewHealthManager
            )

            MigraineAssistantView()
                .modelContainer(container)
                .environment(previewInsightManager)
        } else {
            Text("Requires iOS 18 (Apple Intelligence)")
        }
    }
}
