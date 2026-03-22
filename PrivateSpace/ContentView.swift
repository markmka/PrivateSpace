//
//  ContentView.swift
//  PrivateSpace
//
//  Created by bot on 2026/3/22.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isFirstLaunch {
                SetupView()
            } else if appState.isLocked {
                UnlockView()
            } else {
                NavigationStack {
                    MainListView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
