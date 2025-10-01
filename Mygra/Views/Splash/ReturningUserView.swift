//
//  ReturningUserView.swift
//  Mygra
//
//  Created by Nick Molargik on 9/25/25.
//

import SwiftUI

struct ReturningUserView: View {
    @Binding var isSyncing: Bool
    @Binding var errorMessage: String?
    var onRetry: () -> Void
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome back!")
                    .font(.title2).bold()
                Text("If you started on another Apple device, it can take up to 30 minutes for the initial sync to occur. Hang tight!")
                    .foregroundStyle(.secondary)

                if isSyncing {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking iCloud for your data…")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.thinMaterial)
                            .shadow(radius: 5)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let msg = errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(msg)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(radius: 5)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                HStack {
                    Button("Close") { onClose() }
                        .foregroundStyle(.white)
                        .bold()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .adaptiveGlass(tint: .gray)

                    Spacer()

                    Button("Retry") { onRetry() }
                        .foregroundStyle(.white)
                        .bold()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .adaptiveGlass(tint: .mygraBlue)
                        .disabled(isSyncing)
                        .opacity(isSyncing ? 0.7 : 1.0)
                }
            }
            .padding()
            .animation(.easeInOut(duration: 0.25), value: isSyncing)
            .animation(.easeInOut(duration: 0.25), value: errorMessage)
            .navigationTitle("Returning User")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ReturningUserView(isSyncing: .constant(true), errorMessage: .constant(nil), onRetry: {}, onClose: {})
}
