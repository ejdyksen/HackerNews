// Standalone listing screen for phone navigation. This binds one listing model
// into a scrollable feed with refresh, pagination, and empty/error states.
import SwiftUI

struct ListingView: View {
    let destination: HNListingDestination
    let onUpdateDestination: (HNListingDestination) -> Void
    let onSelectItem: (HNItem) -> Void
    @EnvironmentObject private var cache: AppCache

    var body: some View {
        ListingViewBody(
            destination: destination,
            listing: cache.listing(for: destination),
            onUpdateDestination: onUpdateDestination,
            onSelectItem: onSelectItem
        )
    }
}

private struct ListingViewBody: View {
    let destination: HNListingDestination
    @ObservedObject var listing: HNListing
    let onUpdateDestination: (HNListingDestination) -> Void
    let onSelectItem: (HNItem) -> Void
    @State private var showRefresh = false

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if destination.explainer != nil {
                    ListingContextHeader(
                        destination: destination,
                        onUpdateDestination: onUpdateDestination
                    )
                    .listRowSeparator(.hidden)
                }

                ForEach(listing.items) { item in
                    ListingItemCell(item: item) {
                        onSelectItem(item)
                    }
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
            .task(id: destination) {
                listing.loadInitialContent()
            }
            .onAppear {
                if listing.pendingFreshLoad {
                    listing.pendingFreshLoad = false
                    listing.reset()
                    listing.loadInitialContent()
                }
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
            .listStyle(.plain)
            .navigationTitle(destination.displayName)
            .lastUpdatedToast(listing.lastUpdated, style: .refresh, source: "listing/\(destination.logKey)") {
                if let firstID = listing.items.first?.id {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(firstID, anchor: .top)
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    listing.loadMoreContent(reload: true)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ListingView(
                destination: .news,
                onUpdateDestination: { _ in },
                onSelectItem: { _ in }
            )
            .environmentObject(AppCache())
        }
    }
}
