// Listing column used by the unified NavigationSplitView root.
import SwiftUI

struct ListingContentColumn: View {
    let destination: HNListingDestination
    @Binding var selectedItem: HNItem?
    let onUpdateDestination: (HNListingDestination) -> Void
    let onShowSettings: () -> Void
    @EnvironmentObject private var cache: AppCache

    var body: some View {
        ListingContentColumnBody(
            destination: destination,
            listing: cache.listing(for: destination),
            selectedItem: $selectedItem,
            onUpdateDestination: onUpdateDestination,
            onShowSettings: onShowSettings
        )
    }
}

private struct ListingContentColumnBody: View {
    let destination: HNListingDestination
    @ObservedObject var listing: HNListing
    @Binding var selectedItem: HNItem?
    let onUpdateDestination: (HNListingDestination) -> Void
    let onShowSettings: () -> Void
    @State private var now = Date.now
    @State private var isShowingToastRefresh = false

    var body: some View {
        ScrollViewReader { proxy in
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
            .navigationSubtitle(listing.lastUpdated.map { "Updated \(relativeTimeString(from: $0, now: now))" } ?? " ")
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onShowSettings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
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
                source: "column/\(destination.logKey)",
                isRefreshing: isShowingToastRefresh,
                prefersSystemRefresh: true,
                onBeforeRefresh: {
                    await MainActor.run {
                        isShowingToastRefresh = true
                        if let firstID = listing.items.first?.id {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(firstID, anchor: .top)
                            }
                        }
                    }
                    try? await Task.sleep(nanoseconds: 350_000_000)
                },
                onAfterRefresh: {
                    await MainActor.run {
                        isShowingToastRefresh = false
                    }
                },
                onRefresh: {
                    await listing.loadMoreContent(reload: true)
                }
            )
        }
    }
}
