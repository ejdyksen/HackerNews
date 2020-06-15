//
//  DetailView.swift
//  HackerNews
//
//  Created by ejd on 9/29/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import SwiftUI

struct DetailView: View {
    @ObservedObject var item: Item
    
    let bodyFont = Font.system(size: 13.5)

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
                        .font(self.bodyFont)
                        .foregroundColor(Color.orange)
                    ForEach(comment.paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(self.bodyFont)
                    }
                }.padding(.leading, self.indentPixels(comment.indentLevel))
            }
        }.navigationBarTitle("\(item.comments.count) comments", displayMode: .inline)
        .onAppear(perform: reload)
    }
    
    func reload() {
        item.loadComments()
    }
    
    func indentPixels(_ level: Int) -> CGFloat {
        return 12 * CGFloat(level)
    }

}

#if DEBUG
struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DetailView(item: itemWithComments())
        }
    }
}
#endif
