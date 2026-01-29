//
//  AuthenticationView.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import SwiftUI

/// Authentication view for Feedly OAuth login.
struct AuthenticationView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon and title
            VStack(spacing: 16) {
                Image(systemName: "newspaper")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("RSS Reader")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("A native macOS RSS reader powered by Feedly")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Login section
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                    Text("Authenticating...")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        signInWithFeedly()
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key")
                            Text("Sign in with Feedly")
                        }
                        .frame(minWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
            }

            Spacer()

            // Footer
            Text("Keyboard-driven RSS reading experience")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(minWidth: 400, minHeight: 300)
        .padding(40)
    }

    private func signInWithFeedly() {
        isLoading = true
        errorMessage = nil
        // OAuth flow will be implemented in a later story
    }
}
