//
//  HackerNewsApp.swift
//  Shared
//
//  Created by E.J. Dyksen on 11/22/20.
//

import SwiftUI

@main
struct HackerNewsApp: App {
    var body: some Scene {
        WindowGroup {
            let service = HackerNewsService()
            let contentView = ContentView()
            contentView.environmentObject(service)
        }
    }
}
