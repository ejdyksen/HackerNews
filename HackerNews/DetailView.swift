//
//  DetailView.swift
//  HackerNews
//
//  Created by ejd on 9/29/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import Foundation
import SwiftUI

struct DetailView: View {
    let item: Item
    let comments: [Comment] = sampleComments

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
                                
                ForEach(comments) { comment in
                    Text(comment.body)
                }
        }.navigationBarTitle("\(comments.count) comments", displayMode: .inline)
    }
    
}


struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DetailView(item: itemOne)
        }
    }
}
