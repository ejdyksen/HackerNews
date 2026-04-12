//
//  HackerNewsApp.swift
//  Shared
//
//  Created by E.J. Dyksen on 11/22/20.
//

import SwiftUI

@main
struct HackerNewsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AdaptiveHomeView()
                .handleURLs()
                .environmentObject(appState)
        }
    }
}
