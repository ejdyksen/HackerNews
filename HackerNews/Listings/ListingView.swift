import SwiftUI

struct ListingView: View {
    @ObservedObject var listing: HNListing

    @State private var showRefresh = false

    let title: String

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
            listing.loadMoreContent(reload: true) {
                showRefresh = false
            }
        }
        .task {
            listing.loadInitialContent()
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
        .navigationTitle(title)
        .navigationDestination(for: HNItem.self) { item in
            ItemDetailView(item: item)
        }
    }
}

struct NewsListing: View {
    @StateObject var listingDataSource = HNListing(.news)

    var body: some View {
        ListingView(listing: listingDataSource, title: "Top Stories")
    }
}

struct AskListing: View {
    @StateObject var listingDataSource = HNListing(.ask)

    var body: some View {
        ListingView(listing: listingDataSource, title: "Ask HN")
    }
}

struct ShowListing: View {
    @StateObject var listingDataSource = HNListing(.show)

    var body: some View {
        ListingView(listing: listingDataSource, title: "Show HN")
    }
}

struct NewListing: View {
    @StateObject var listingDataSource = HNListing(.newest)

    var body: some View {
        ListingView(listing: listingDataSource, title: "New Stories")
    }
}

struct JobsListing: View {
    @StateObject var listingDataSource = HNListing(.jobs)

    var body: some View {
        ListingView(listing: listingDataSource, title: "Jobs")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView() {
            ListingView(listing: HNListing.exampleService(), title: "Top Stories")
        }
    }
}
