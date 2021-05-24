//
//  DetailView.swift
//  HackerNews
//
//  Created by ejd on 9/29/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import SwiftUI

struct ItemDetailView: View {
    @ObservedObject var item: HNItem

    var body: some View {
        List {
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(item.subheading)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
                            
            ForEach(item.comments) { comment in
                CommentCell(comment: comment)
            }
        }
        .navigationTitle("\(item.commentCount) comments")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            item.loadDetails()
        }
    }

}


//#if DEBUG
//struct DetailView_Previews: PreviewProvider {
//    static var previews: some View {
//        NavigationView {
//            CommentView(item: itemWithComments())
//        }
//    }
//}
//#endif
