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
                    ForEach(ListingType.allCases, id: \.self) { listingType in
                        NavigationLink(value: listingType) {
                            Text(listingType.displayName)
                        }
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
            .navigationDestination(for: ListingType.self) { listingType in
                ListingView(listingType: listingType)
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
