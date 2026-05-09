// Story listing screen used inside the compact NavigationStack. This avoids
// split-view selection bindings on iPhone while sharing the row content and
// listing models used by the regular-width column.
import SwiftUI

struct StackListingView: View {
    let destination: HNListingDestination
    let onUpdateDestination: (HNListingDestination) -> Void
    let onSelectItem: (HNItem) -> Void
    @EnvironmentObject private var cache: AppCache

    var body: some View {
        StackListingViewBody(
            destination: destination,
            listing: cache.listing(for: destination),
            onUpdateDestination: onUpdateDestination,
            onSelectItem: onSelectItem
        )
    }
}

private struct StackListingViewBody: View {
    let destination: HNListingDestination
    @ObservedObject var listing: HNListing
    let onUpdateDestination: (HNListingDestination) -> Void
    let onSelectItem: (HNItem) -> Void
    @State private var now = Date.now

    private var navigationSubtitle: String {
        listing.lastUpdated.map { "Updated \(relativeTimeString(from: $0, now: now))" } ?? " "
    }

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

                if listing.hasMoreContent {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .onAppear { listing.loadMoreContent() }
                }
            }
            .listStyle(.plain)
            .navigationTitle(destination.displayName)
            .navigationSubtitle(navigationSubtitle)
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
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
            .lastUpdatedToast(
                listing.lastUpdated,
                style: .refresh,
                placement: .top,
                source: "stack/\(destination.logKey)",
                prefersSystemRefresh: true,
                onBeforeRefresh: {
                    await MainActor.run {
                        if let firstID = listing.items.first?.id {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(firstID, anchor: .top)
                            }
                        }
                    }
                    try? await Task.sleep(nanoseconds: 350_000_000)
                },
                onRefresh: {
                    await listing.loadMoreContent(reload: true)
                }
            )
        }
    }
}

#if DEBUG
struct StackListingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StackListingView(
                destination: .news,
                onUpdateDestination: { _ in },
                onSelectItem: { _ in }
            )
            .environmentObject(AppCache())
        }
    }
}
#endif
