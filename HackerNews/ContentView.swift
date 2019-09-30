//
//  ContentView.swift
//  HackerNews
//
//  Created by ejd on 9/22/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import SwiftUI

private let dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .medium
    return dateFormatter
}()

struct ContentView: View {
    @EnvironmentObject private var hnService: HackerNewsService

    var body: some View {
        NavigationView {
            MasterView(hnService: hnService)
                .navigationBarTitle(Text("Top Stories"))
                .navigationBarItems(
                    leading: EditButton(),
                    trailing: Button(
                        action: {
                            let _ = self.hnService.load()
                        }
                    ) {
                        Text("Load")
                    }
                )
            DetailView()
        }.navigationViewStyle(DoubleColumnNavigationViewStyle())
    }
}

struct MasterView: View {
    @ObservedObject var hnService: HackerNewsService

    var body: some View {
        List {
            ForEach(hnService.topStories, id: \.id) { story in
                NavigationLink(
                    destination: DetailView()
                ) {
                    Text(story.title)
                }
            }
        }
    }
}

struct DetailView: View {
//    var selectedDate: Date?

    var body: some View {
        Text("Detail view content goes here")
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
