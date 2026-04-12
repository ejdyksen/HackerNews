import SwiftUI

struct CommentCell: View {
    @ObservedObject var comment: HNComment
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggle()
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
                        Text(relativeTimeString(from: comment.age))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .lineLimit(1)
                    .padding(.leading, CGFloat(comment.indentLevel * 12))

                    if !isCollapsed {
                        Text(comment.content)
                            .padding(.leading, CGFloat(comment.indentLevel * 12))
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .buttonStyle(PlainButtonStyle())

            if !isCollapsed && comment.canUpvote {
                Menu {
                    if !comment.isUpvoted && !comment.isDownvoted {
                        Button(action: { Task { try? await comment.upvote() } }) {
                            Label("Upvote", systemImage: "hand.thumbsup")
                        }
                        Button(action: { Task { try? await comment.downvote() } }) {
                            Label("Downvote", systemImage: "hand.thumbsdown")
                        }
                    } else {
                        Button(action: { Task { try? await comment.unvote() } }) {
                            Label("Unvote", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: 44)
                }
            }

            Divider()
        }
    }
}

struct CommentCell_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ItemDetailView(item: HNItem.itemWithComments())
        }

        CommentCell(
            comment: HNItem.itemWithComments().rootComments[0],
            isCollapsed: false,
            onToggle: {}
        )
        .previewLayout(.sizeThatFits)
    }
}
