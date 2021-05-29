//
//  CommentCell.swift
//  HackerNews
//
//  Created by E.J. Dyksen on 5/23/21.
//

import SwiftUI

struct CommentCell: View {
    var comment: HNComment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(comment.author)
                .font(.system(size: 15))
                .foregroundColor(.accentColor)
                .padding(.vertical, 1)

            ForEach(comment.paragraphs, id: \.self) { paragraph in
                Text(paragraph)
            }
            .padding(.bottom, 2)
        }.padding(.leading, CGFloat(comment.indentLevel * 12))

    }
}

struct CommentCell_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CommentCell(comment: comment3)
                .previewLayout(.sizeThatFits)
                .padding(10)
        }
    }
}
