//
//  ContentView.swift
//  HackerNews
//
//  Created by ejd on 9/22/19.
//  Copyright 2019 ejd. All rights reserved.
//

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
            if (!showRefresh) {
                if listing.items.isEmpty {
                    HStack(alignment: .center, spacing: 10) {
                        ProgressView()
                        Text("Loading").foregroundColor(.secondary)
                    }
                } else if listing.hasMoreContent {
                    HStack(alignment: .center, spacing: 10) {
                        ProgressView()
                        Text("Loading more...").foregroundColor(.secondary)
                    }
                    .onAppear {
                        listing.loadMoreContent()
                    }
                }
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

        .listStyle(PlainListStyle())
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing:
                HStack {
                    Button {
                        listing.loadMoreContent(reload: true)
                    } label: {
                        Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                    }
                }
        )
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
