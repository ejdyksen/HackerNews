//
//  CommentCell.swift
//  HackerNews
//
//  Created by E.J. Dyksen on 5/23/21.
//

import SwiftUI

struct CommentCell: View {
    var comment: HNComment
    
    let bodyFont = Font.system(size: 14)
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(comment.author)
                .font(.system(size: 15))
                .foregroundColor(.accentColor)
                .padding(.vertical, 1)
            ForEach(comment.paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(bodyFont)
                    .padding(.bottom, 1)
            }
            .padding(.bottom, 2)
        }.padding(.leading, self.indentPixels(comment.indentLevel))

    }
    
    func indentPixels(_ level: Int) -> CGFloat {
        return 12 * CGFloat(level)
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
