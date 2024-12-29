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
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text(comment.author)
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Text(expanded ? comment.age : comment.paragraphs[0])
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .lineLimit(1)
                .padding(.leading, CGFloat(comment.indentLevel * 12))

                if expanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(comment.paragraphs, id: \.self) { paragraph in
                            Text(paragraph)
                        }
                    }
                    .padding(.leading, CGFloat(comment.indentLevel * 12))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 8)

            Divider()

            if expanded && comment.children.count > 0 {
                ForEach(comment.children) { child in
                    CommentCell(comment: child)
                }
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .background(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .opacity(isPressed ? 1 : 0)
        )
        .contextMenu {
            Button(action: {
                // Upvote action to be implemented
            }) {
                Label("Upvote", systemImage: "arrow.up")
            }
            
            Button(action: {
                // View profile action to be implemented
            }) {
                Label("View Profile", systemImage: "person")
            }
            
            Button(action: {
                // Reply action to be implemented
            }) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.expanded.toggle()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
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
