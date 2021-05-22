//
//  ContentView.swift
//  HackerNews
//
//  Created by ejd on 9/22/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var service: HackerNewsService

    var body: some View {
        NavigationView {
            MasterView(items: service.topStories)
                .navigationTitle(Text("Top Stories"))
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button("Reload") {
                            self.service.load()
                        }
                    }
                }

            if (service.topStories.count > 0 ) {
                DetailView(item: service.topStories.first!)
            }
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .accentColor(.orange)
        .onAppear(perform: reload)
    }

    func reload() {
        self.service.reload()
    }
}

struct MasterView: View {
    var items: [Item]

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink(destination: DetailView(item: item)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.title)
                                .foregroundColor(.primary)

                            Text(item.subheading)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(item.commentSummary)
                            .font(.subheadline)
                            .foregroundColor(Color.gray)
                            .padding(.leading)
                    }
                }
            }
            .padding(2)
        }
        .listStyle(PlainListStyle())
        .animation(.none)
    }
}


#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(HackerNewsService.exampleService())
    }
}
#endif
