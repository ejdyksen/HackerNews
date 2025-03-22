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
                        Text(expanded ? comment.age : String(comment.content.prefix(50)))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .lineLimit(1)
                    .padding(.leading, CGFloat(comment.indentLevel * 12))

                    if expanded {
                        Text(.init(comment.content))
                            .padding(.leading, CGFloat(comment.indentLevel * 12))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Rectangle()
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            if expanded {
                Menu {
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
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: 44)
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
