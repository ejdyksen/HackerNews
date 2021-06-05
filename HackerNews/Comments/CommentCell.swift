//
//  CommentCell.swift
//  HackerNews
//
//  Created by E.J. Dyksen on 5/23/21.
//

import SwiftUI

struct CommentCell: View {
    var comment: HNComment
    
    @State var expanded = true

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text(comment.author)
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Text(expanded ? comment.age : comment.paragraphs[0])
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .transition(.identity)
            }
            .lineLimit(1)
            .padding(.leading, CGFloat(comment.indentLevel * 12))


            if (expanded) {
                ForEach(comment.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                }
                .padding(.leading, CGFloat(comment.indentLevel * 12))
                .transition(.identity)

                Divider()

                if (comment.children.count > 0 ) {
                    ForEach(comment.children) { child in
                        CommentCell(comment: child)
                    }

                }

            } else {
                Divider()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeIn(duration: 0.1)) {
                self.expanded.toggle()
            }
        }
    }
}

struct CommentCell_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            CommentCell(comment: HNComment.itemWithComments().rootComments[0])
                .previewLayout(.sizeThatFits)
                .padding(10)
        }
    }
}
