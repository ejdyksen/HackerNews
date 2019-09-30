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
                .navigationBarTitle(Text("Top Stories"), displayMode: .automatic)
                .navigationBarItems(
                    leading: EditButton(),
                    trailing: Button(
                        action: {
                            self.service.load()
                        }
                    ) {
                        Text("Load")
                    }
                )
//            DetailView(item: hnService.topStories.first!)
        }.navigationViewStyle(DoubleColumnNavigationViewStyle())
            .accentColor(.orange)
    }
}

struct MasterView: View {
//    @ObservedObject var hnService: HackerNewsService
    var items: [Item]

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink(destination: DetailView(item: item)) {
                    VStack(alignment: .leading) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(item.subheading)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }.animation(.none)
    }
}

 

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(HackerNewsService.exampleService())
    }
}
