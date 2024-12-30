import SwiftUI

struct CommentCell: View {
    @ObservedObject var comment: HNComment

    @State var expanded = true
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Comment content section
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.expanded.toggle()
                }
            }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline) {
                        if comment.canUpvote {
                            Group {
                                if comment.isUpvoted {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .foregroundColor(.orange)
                                } else if comment.isDownvoted {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .font(.caption)
                            .frame(width: 12, height: 12)
                        }
                        Text(comment.author)
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        Text(expanded ? comment.age : String(comment.content.characters.prefix(50)))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .lineLimit(1)
                    .padding(.leading, CGFloat(comment.indentLevel * 12))

                    if expanded {
                        Text(comment.content)
                            .padding(.leading, CGFloat(comment.indentLevel * 12))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Rectangle()
                        .fill(Color(.systemBackground))
                        .opacity(isPressed ? 1 : 0)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isPressed = false
                                }
                            }
                        }
                    }
            )
            .contextMenu {
                if comment.canUpvote {
                    if !comment.isUpvoted && !comment.isDownvoted {
                        Button(action: {
                            Task {
                                try? await comment.upvote()
                            }
                        }) {
                            Label("Upvote", systemImage: "hand.thumbsup")
                        }
                        
                        Button(action: {
                            Task {
                                try? await comment.downvote()
                            }
                        }) {
                            Label("Downvote", systemImage: "hand.thumbsdown")
                        }
                    } else {
                        Button(action: {
                            Task {
                                try? await comment.unvote()
                            }
                        }) {
                            Label("Unvote", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
                
                Button(action: {
                    UIPasteboard.general.string = comment.content.description
                }) {
                    Label("Copy Text", systemImage: "doc.on.doc")
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

            Divider()

            // Children section
            if expanded && comment.children.count > 0 {
                ForEach(comment.children) { child in
                    CommentCell(comment: child)
                }
            }
        }
        .padding(.horizontal, 1)
        .clipped()
    }
}

struct CommentCell_Previews: PreviewProvider {

    static var previews: some View {
        NavigationView {
            ItemDetailView(item: HNItem.itemWithComments())
        }

        CommentCell(comment: HNItem.itemWithComments().rootComments[0])
            .previewLayout(.sizeThatFits)
    }

}
