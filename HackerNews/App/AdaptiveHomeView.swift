// Root container that switches between phone and iPad navigation layouts while
// keeping selection, deep-link handling, and account UI in one place.
import SwiftUI

struct AdaptiveHomeView: View {
    @AppStorage("showExtraLists") private var showExtraLists = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var cache: AppCache
    @State private var selectedListing: HNListingDestination? = .news
    @State private var rememberedListings: [ListingKind: HNListingDestination] = [
        .news: .news
    ]
    @State private var selectedItem: HNItem?
    @State private var detailPath = NavigationPath()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingSettings = false

    private var currentListing: HNListingDestination { selectedListing ?? .news }

    private var selectedListingKind: Binding<ListingKind?> {
        Binding(
            get: { selectedListing?.kind },
            set: { newKind in
                guard let newKind else { return }
                selectedListing = rememberedListings[newKind] ?? newKind.defaultDestination
            }
        )
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebarView
            } content: {
                ListingContentColumn(
                    destination: currentListing,
                    selectedItem: $selectedItem,
                    onUpdateDestination: updateListing
                )
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 500)
            } detail: {
                NavigationStack(path: $detailPath) {
                    if let item = selectedItem {
                        ItemDetailView(
                            item: item,
                            onShowUserProfile: { username in
                                detailPath.append(HNUserRoute(username: username))
                            },
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
                .navigationDestination(for: HNUserRoute.self) { route in
                    UserProfileView(route: route)
                }
                .id(selectedItem?.id)
            }
            .navigationSplitViewStyle(.balanced)
            .onChange(of: selectedListing) {
                selectedItem = nil
                detailPath = NavigationPath()
            }
            .onChange(of: selectedItem?.id) { _, _ in
                detailPath = NavigationPath()
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
                detailPath = NavigationPath()
                columnVisibility = .detailOnly
                appState.deepLinkItemID = nil
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onChange(of: showExtraLists) { _, isEnabled in
                guard !isEnabled, currentListing.kind.isExtraList else { return }
                selectedListing = .news
                selectedItem = nil
            }
        } else {
            HomeView()
        }
    }

    @ViewBuilder
    private var sidebarView: some View {
        List(selection: selectedListingKind) {
            Section(ListingSection.stories.rawValue) {
                ForEach(ListingKind.storyKinds, id: \.self) { kind in
                    Label(kind.displayName, systemImage: kind.iconName)
                        .tag(kind as ListingKind?)
                }
            }
            if showExtraLists {
                Section(ListingSection.lists.rawValue) {
                    ForEach(ListingKind.listKinds, id: \.self) { kind in
                        Label(kind.displayName, systemImage: kind.iconName)
                            .tag(kind as ListingKind?)
                    }
                }
            }
        }
        .navigationTitle("Home")
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private func updateListing(_ destination: HNListingDestination) {
        selectedListing = destination
        rememberedListings[destination.kind] = destination
    }
}

struct ListingContentColumn: View {
    let destination: HNListingDestination
    @Binding var selectedItem: HNItem?
    let onUpdateDestination: (HNListingDestination) -> Void
    @EnvironmentObject private var cache: AppCache

    var body: some View {
        ListingContentColumnBody(
            destination: destination,
            listing: cache.listing(for: destination),
            selectedItem: $selectedItem,
            onUpdateDestination: onUpdateDestination
        )
    }
}

private struct ListingContentColumnBody: View {
    let destination: HNListingDestination
    @ObservedObject var listing: HNListing
    @Binding var selectedItem: HNItem?
    let onUpdateDestination: (HNListingDestination) -> Void

    var body: some View {
        List(selection: $selectedItem) {
            if destination.explainer != nil {
                ListingContextHeader(
                    destination: destination,
                    onUpdateDestination: onUpdateDestination
                )
                .listRowSeparator(.hidden)
            }

            ForEach(listing.items) { item in
                NavigationLink(value: item) {
                    ListingItemCellContent(
                        item: item,
                        isSelected: selectedItem?.id == item.id,
                        leadingInset: 6
                    )
                }
            }

            if listing.hasMoreContent {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .onAppear { listing.loadMoreContent() }
            }
        }
        .navigationTitle(destination.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: destination) {
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
        .lastUpdatedToast(listing.lastUpdated, source: "column/\(destination.logKey)")
    }
}
