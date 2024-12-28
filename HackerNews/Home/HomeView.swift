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
    case newest
    case show
    case jobs
}

struct HomeView: View {
    @SceneStorage("ContentView.selectedProduct") private var selectedListing: String?
    @State private var path = NavigationPath()
    @StateObject private var authController = AuthController.shared
    @State private var showingLoginSheet = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: HomeDestination.news) {
                        Text("Top stories")
                    }
                    NavigationLink(value: HomeDestination.newest) {
                        Text("New Stories")
                    }
                    NavigationLink(value: HomeDestination.ask) {
                        Text("Ask HN")
                    }
                    NavigationLink(value: HomeDestination.show) {
                        Text("Show HN")
                    }
                    NavigationLink(value: HomeDestination.jobs) {
                        Text("Jobs")
                    }
                }

                Section {
                    if authController.isLoggedIn {
                        HStack {
                            Text(authController.username ?? "User")
                                .font(.subheadline)
                            Spacer()
                        }
                        Button("Logout") {
                            authController.logout()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Login") {
                            showingLoginSheet = true
                        }
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
                case .newest:
                    NewListing()
                case .show:
                    ShowListing()
                case .jobs:
                    JobsListing()
                }
            }
            .sheet(isPresented: $showingLoginSheet) {
                LoginView()
            }
        }
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
