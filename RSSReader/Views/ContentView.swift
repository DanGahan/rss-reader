//
//  ContentView.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import SwiftUI

/// Root content view that switches between authentication and main views.
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainView()
            } else {
                AuthenticationView()
            }
        }
    }
}