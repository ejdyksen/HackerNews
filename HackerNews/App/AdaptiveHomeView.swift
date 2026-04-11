import SwiftUI

struct AdaptiveHomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedListing: ListingType? = .news
    @State private var selectedItem: HNItem? = nil
    @StateObject private var authController = AuthController.shared
    @State private var showingLoginSheet = false

    private var currentListing: ListingType { selectedListing ?? .news }

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                sidebarView
            } content: {
                ListingContentColumn(
                    listingType: currentListing,
                    selectedItem: $selectedItem
                )
                .id(currentListing)
            } detail: {
                if let item = selectedItem {
                    ItemDetailView(item: item)
                } else {
                    ContentUnavailableView {
                        Label("Select a story", systemImage: "newspaper")
                    } description: {
                        Text("Choose a story from the list.")
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
            .onChange(of: selectedListing) { _, _ in
                selectedItem = nil
            }
            .sheet(isPresented: $showingLoginSheet) {
                LoginView()
            }
        } else {
            HomeView()
        }
    }

    @ViewBuilder
    private var sidebarView: some View {
        List(selection: $selectedListing) {
            Section("Stories") {
                ForEach(ListingType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.iconName)
                        .tag(type as ListingType?)
                }
            }
            Section("Account") {
                if authController.isLoggedIn {
                    Text(authController.username ?? "User")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
        .navigationTitle("HN")
        .listStyle(.sidebar)
    }
}

struct ListingContentColumn: View {
    let listingType: ListingType
    @Binding var selectedItem: HNItem?
    @StateObject private var listing: HNListing

    init(listingType: ListingType, selectedItem: Binding<HNItem?>) {
        self.listingType = listingType
        self._selectedItem = selectedItem
        self._listing = StateObject(wrappedValue: HNListing(listingType))
    }

    var body: some View {
        List(selection: $selectedItem) {
            ForEach(listing.items) { item in
                ListingItemCellContent(item: item)
                    .tag(item as HNItem?)
            }
            if listing.hasMoreContent {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .onAppear { listing.loadMoreContent() }
            }
        }
        .navigationTitle(listingType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { listing.loadInitialContent() }
        .refreshable {
            await withCheckedContinuation { continuation in
                listing.loadMoreContent(reload: true) {
                    continuation.resume()
                }
            }
        }
        .overlay {
            if listing.isLoading && listing.items.isEmpty {
                ProgressView("Loading...")
            }
        }
    }
}
