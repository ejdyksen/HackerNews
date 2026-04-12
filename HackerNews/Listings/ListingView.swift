import SwiftUI

struct ListingView: View {
    let listingType: ListingType
    @StateObject private var listing: HNListing
    @State private var showRefresh = false

    init(listingType: ListingType) {
        self.listingType = listingType
        self._listing = StateObject(wrappedValue: HNListing(listingType))
    }

    var body: some View {
        List {
            Text(listingType.displayName)
                .font(.largeTitle.bold())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 8, trailing: 20))

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
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HNItem.self) { item in
            ItemDetailView(item: item)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ListingView(listingType: .news)
        }
    }
}
