//
//  ContentView.swift
//  HackerNews
//
//  Created by ejd on 9/22/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import SwiftUI

struct ListingView: View {
    @ObservedObject var listing: HNListing
    
    let title: String

    var body: some View {
        NavigationView {
            List(listing.items) { item in
                ListingItemCell(item: item)
                    .onAppear {
                        listing.loadMoreContentIfNeeded(currentItem: item)
                    }

            }
            .listStyle(PlainListStyle())
            .navigationTitle(Text(title))
            .navigationBarItems(leading:
                HStack {
                    Button {
                        print("NYI")
                    } label: {
                        Image(systemName: "person")
                    }
                }, trailing:
                    HStack {
                        Button {
                            listing.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
            )
        }
    }
}

struct NewsListing: View {
    @StateObject var listingDataSource = HNListing(listingType: "news")

    var body: some View {
        ListingView(listing: listingDataSource, title: "Top Stories")
    }
}

struct AskListing: View {
    @StateObject var listingDataSource = HNListing(listingType: "ask")

    var body: some View {
        ListingView(listing: listingDataSource, title: "Ask HN")
    }
}

struct ShowListing: View {
    @StateObject var listingDataSource = HNListing(listingType: "show")

    var body: some View {
        ListingView(listing: listingDataSource, title: "Show HN")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ListingView(listing: HNListing.exampleService(), title: "Top Stories")
    }
}
