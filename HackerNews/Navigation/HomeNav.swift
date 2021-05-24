//
//  NavigationView.swift
//  HackerNews
//
//  Created by E.J. Dyksen on 5/23/21.
//

import SwiftUI

struct HomeNav: View {

    var body: some View {
        TabView(selection: /*@START_MENU_TOKEN@*//*@PLACEHOLDER=Selection@*/.constant(1)/*@END_MENU_TOKEN@*/) {
            NewsListing().tabItem {
                Image(systemName: "house")
                Text("Home")
            }.tag(1)
            AskListing().tabItem {
                Image(systemName: "questionmark.circle")
                Text("Ask HN")
            }.tag(2)
            ShowListing().tabItem {
                Image(systemName: "binoculars")
                Text("Show HN")
            }.tag(3)
        }
    }
}
