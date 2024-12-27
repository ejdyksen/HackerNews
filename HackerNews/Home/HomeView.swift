//
//  Home.swift
//  HackerNews (iOS)
//
//  Created by E.J. Dyksen on 6/22/21.
//

import SwiftUI

enum HomeDestination {
    case news
    case ask
}
struct HomeView: View {
    @SceneStorage("ContentView.selectedProduct") private var selectedListing: String?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: HomeDestination.news) {
                        Text("Top stories")
                    }
                    NavigationLink(value: HomeDestination.ask) {
                        Text("Ask HN")
                    }
                }
            }
            .navigationTitle("Home")
            .listStyle(.grouped)
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .news:
                    NewsListing()
                case .ask:
                    AskListing()
                }
            }
        }
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
