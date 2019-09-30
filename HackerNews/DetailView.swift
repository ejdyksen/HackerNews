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
    @ObservedObject var item: Item

    func reload() {
        item.loadComments()
    }
    
    func indentPixels(_ level: Int) -> CGFloat {
        return 10 * CGFloat(level)
    }

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
                VStack(alignment: .leading) {
                    Text(comment.author)
                        .fontWeight(.bold)
                    Spacer()
                    Text(comment.body)
                }.padding(.leading, self.indentPixels(comment.indentLevel))
            }
        }.navigationBarTitle("\(item.comments.count) comments", displayMode: .inline)
        .onAppear(perform: reload)
    }
    
}

/*
struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DetailView(item: itemOne)
        }
    }
}
*/
