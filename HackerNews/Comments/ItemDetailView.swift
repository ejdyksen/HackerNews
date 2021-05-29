//
//  DetailView.swift
//  HackerNews
//
//  Created by ejd on 9/29/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import SwiftUI

struct ItemDetailContainerView: View {
    @ObservedObject var item: HNItem

    var body: some View {
        ItemDetailView(item: item).onAppear {
            item.loadDetails()
        }
    }
}

struct ItemDetailView: View {
    @ObservedObject var item: HNItem

    let bodyFont = Font.system(size: 15)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {

                NavigationLink(destination: WebView(initialUrl: item.storyLink)) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .padding(.top, 10)
                }

                

                Text(item.subheading)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()
                if (item.paragraphs.count > 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(item.paragraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .padding(.bottom, 3)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)

                        }
                    }
                    Divider()
                }

            }

            LazyVStack(alignment: .leading) {
                ForEach(item.comments) { comment in
                    CommentCell(comment: comment)
                    Divider()
                }
            }
        }
        .padding(.horizontal)
        .navigationTitle("\(item.commentCount) comments")
        .navigationBarTitleDisplayMode(.inline)

    }

}


#if DEBUG
struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ItemDetailView(item: HNComment.itemWithComments())
            }
        }
    }
}
#endif
