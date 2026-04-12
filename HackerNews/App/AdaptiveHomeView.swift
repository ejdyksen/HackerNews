// Root container that switches between phone and iPad navigation layouts while
// keeping selection, deep-link handling, and account UI in one place.
import SwiftUI

struct AdaptiveHomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var cache: AppCache
    @State private var selectedListing: ListingType? = .news
    @State private var selectedItem: HNItem?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var authController = AuthController.shared
    @State private var showingLoginSheet = false

    private var currentListing: ListingType { selectedListing ?? .news }

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebarView
            } content: {
                ListingContentColumn(listingType: currentListing, selectedItem: $selectedItem)
            } detail: {
                NavigationStack {
                    if let item = selectedItem {
                        ItemDetailView(
                            item: item,
                            onToggleFullScreen: {
                                withAnimation {
                                    columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                                }
                            },
                            isFullScreen: columnVisibility == .detailOnly
                        )
                    } else {
                        ContentUnavailableView {
                            Label("Select a story", systemImage: "newspaper")
                        } description: {
                            Text("Choose a story from the list.")
                        }
                    }
                }
                .id(selectedItem?.id)
            }
            .navigationSplitViewStyle(.balanced)
            .onChange(of: selectedListing) {
                selectedItem = nil
            }
            .onChange(of: appState.deepLinkItemID) { _, id in
                guard let id else { return }
                if let cached = cache.item(for: id) {
                    selectedItem = cached
                } else {
                    let stub = HNItem(id: id)
                    cache.rememberItem(stub)
                    selectedItem = stub
                }
                columnVisibility = .detailOnly
                appState.deepLinkItemID = nil
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
    @EnvironmentObject private var cache: AppCache

    var body: some View {
        ListingContentColumnBody(
            listingType: listingType,
            listing: cache.listing(for: listingType),
            selectedItem: $selectedItem
        )
    }
}

private struct ListingContentColumnBody: View {
    let listingType: ListingType
    @ObservedObject var listing: HNListing
    @Binding var selectedItem: HNItem?

    var body: some View {
        List {
            ForEach(listing.items) { item in
                Button {
                    selectedItem = item
                } label: {
                    ListingItemCellContent(item: item)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    selectedItem?.id == item.id
                        ? Color.accentColor.opacity(0.12)
                        : nil
                )
            }
            if listing.hasMoreContent {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .onAppear { listing.loadMoreContent() }
            }
        }
        .navigationTitle(listingType.displayName)
        .task {
            listing.loadInitialContent()
            listing.refreshIfStale()
        }
        .onForegroundActivation {
            listing.refreshIfStale()
        }
        .refreshable {
            await listing.loadMoreContent(reload: true)
        }
        .overlay {
            if listing.isLoading && listing.items.isEmpty {
                ProgressView("Loading...")
            } else if let error = listing.loadError, listing.items.isEmpty {
                ContentUnavailableView {
                    Label("Failed to Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { listing.loadMoreContent(reload: true) }
                }
            }
        }
        .lastUpdatedToast(listing.lastUpdated, source: "column/\(listingType)")
    }
}
