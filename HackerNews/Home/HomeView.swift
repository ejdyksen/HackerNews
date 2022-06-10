//
//  Home.swift
//  HackerNews (iOS)
//
//  Created by E.J. Dyksen on 6/22/21.
//

import SwiftUI

struct HomeView: View {
    @SceneStorage("ContentView.selectedProduct") private var selectedListing: String?

    var body: some View {
        NavigationView {
            List {
                Section() {
                    NavigationLink("Top stories", tag: "news", selection: $selectedListing) {
                        NewsListing()
                    }
                    NavigationLink("Ask HN", tag: "ask", selection: $selectedListing) {
                        AskListing()
                    }

                }


            }
            .navigationTitle("Home")
            .listStyle(.grouped)
        }

    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
