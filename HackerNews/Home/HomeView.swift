import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var path = NavigationPath()
    @StateObject private var authController = AuthController.shared
    @State private var showingLoginSheet = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: ListingType.news) {
                        Text("Top stories")
                    }
                    NavigationLink(value: ListingType.newest) {
                        Text("New Stories")
                    }
                    NavigationLink(value: ListingType.ask) {
                        Text("Ask HN")
                    }
                    NavigationLink(value: ListingType.show) {
                        Text("Show HN")
                    }
                    NavigationLink(value: ListingType.jobs) {
                        Text("Jobs")
                    }
                }

                Section {
                    if authController.isLoggedIn {
                        Text(authController.username ?? "User")
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
            .navigationDestination(for: HNItem.self) { item in
                ItemDetailView(item: item)
            }
            .onChange(of: appState.deepLinkItemID) { _, id in
                guard let id else { return }
                path.append(HNItem(id: id))
                appState.deepLinkItemID = nil
            }
            .navigationDestination(for: ListingType.self) { destination in
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
