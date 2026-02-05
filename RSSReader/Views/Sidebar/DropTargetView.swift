//
//  DropTargetView.swift
//  RSSReader
//
//  Created on 2026-02-05.
//

import SwiftUI
import UniformTypeIdentifiers

struct DropTargetView: View {
    let onDrop: ([NSItemProvider]) -> Bool

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .onDrop(of: [UTType.utf8PlainText], isTargeted: nil) { providers in
                onDrop(providers)
            }
    }
}
