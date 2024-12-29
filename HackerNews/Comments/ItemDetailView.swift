//
//  DetailView.swift
//  HackerNews
//
//  Created by ejd on 9/29/19.
//  Copyright 2019 ejd. All rights reserved.
//

import SwiftUI

struct ItemDetailView: View {
    @ObservedObject var item: HNItem

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ItemDetailHeader(item: item)

                ForEach(item.rootComments) { rootComment in
                    CommentCell(comment: rootComment)
                }

                if (item.canLoadMore) {
                    HStack(alignment: .center, spacing: 10) {
                        ProgressView()
                        Text("Loading").foregroundColor(.secondary)
                    }.onAppear { item.loadMoreContent() }
                }

            }.padding(.horizontal)

        }
        .navigationTitle("\(item.commentCount) comments")
        .navigationBarTitleDisplayMode(.inline)
    }

}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ItemDetailView(item: HNComment.itemWithComments())
            }
        }
    }
}
