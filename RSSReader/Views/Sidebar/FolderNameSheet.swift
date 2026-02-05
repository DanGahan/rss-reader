//
//  FolderNameSheet.swift
//  RSSReader
//
//  Created on 2026-02-05.
//

import SwiftUI

/// A sheet for creating or renaming a folder with proper
/// text field focus support.
struct FolderNameSheet: View {
    enum Mode {
        case create
        case rename
    }

    let mode: Mode
    @Binding var folderName: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text(mode == .create ? "New Folder" : "Rename Folder")
                .font(.headline)

            TextField(
                mode == .create ? "Folder name" : "New name",
                text: $folderName
            )
            .textFieldStyle(.roundedBorder)
            .focused($isTextFieldFocused)
            .onSubmit {
                if !folderName.trimmingCharacters(in: .whitespaces).isEmpty {
                    onSave()
                }
            }

            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(mode == .create ? "Create" : "Rename") {
                    onSave()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(
                    folderName.trimmingCharacters(
                        in: .whitespaces
                    ).isEmpty
                )
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}
