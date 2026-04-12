// Standalone listing screen for phone navigation. This binds one listing model
// into a scrollable feed with refresh, pagination, and empty/error states.
import SwiftUI

struct ListingView: View {
    let listingType: ListingType
    @EnvironmentObject private var cache: AppCache

    var body: some View {
        ListingViewBody(
            listingType: listingType,
            listing: cache.listing(for: listingType)
        )
    }
}

private struct ListingViewBody: View {
    let listingType: ListingType
    @ObservedObject var listing: HNListing
    @State private var showRefresh = false

    var body: some View {
        List {
            ForEach(listing.items) { item in
                ListingItemCell(item: item)
            }
            if !showRefresh, listing.hasMoreContent {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .onAppear { listing.loadMoreContent() }
            }
        }
        .refreshable {
            showRefresh = true
            await listing.loadMoreContent(reload: true)
            showRefresh = false
        }
        .task {
            listing.loadInitialContent()
            listing.refreshIfStale()
        }
        .onForegroundActivation {
            listing.refreshIfStale()
        }
        .overlay {
            if listing.isLoading && listing.items.isEmpty {
                ProgressView()
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
        .listStyle(PlainListStyle())
        .navigationTitle(listingType.displayName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Text("Placeholder")
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .lastUpdatedToast(listing.lastUpdated, source: "listing/\(listingType)")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ListingView(listingType: .news)
                .environmentObject(AppCache())
        }
    }
}
