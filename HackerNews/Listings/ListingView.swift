// Standalone listing screen for phone navigation. This binds one listing model
// into a scrollable feed with refresh, pagination, and empty/error states.
import SwiftUI

struct ListingView: View {
    let destination: HNListingDestination
    let onUpdateDestination: (HNListingDestination) -> Void
    @EnvironmentObject private var cache: AppCache

    var body: some View {
        ListingViewBody(
            destination: destination,
            listing: cache.listing(for: destination),
            onUpdateDestination: onUpdateDestination
        )
    }
}

private struct ListingViewBody: View {
    let destination: HNListingDestination
    @ObservedObject var listing: HNListing
    let onUpdateDestination: (HNListingDestination) -> Void
    @State private var showRefresh = false

    var body: some View {
        List {
            if destination.explainer != nil {
                ListingContextHeader(
                    destination: destination,
                    onUpdateDestination: onUpdateDestination
                )
                .listRowSeparator(.hidden)
            }

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
        .task(id: destination) {
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
        .listStyle(.plain)
        .navigationTitle(destination.displayName)
        .lastUpdatedToast(listing.lastUpdated, source: "listing/\(destination.logKey)")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ListingView(destination: .front(day: HNListingDestination.todayDayString)) { _ in }
                .environmentObject(AppCache())
        }
    }
}
