// Row rendering for one flattened comment in the thread view. This handles the
// collapse gesture, indentation, and per-comment vote actions.
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
            .contextMenu {
                if comment.canUpvote {
                    if !comment.isUpvoted && !comment.isDownvoted {
                        Button { Task { try? await comment.upvote() } } label: {
                            Label("Upvote", systemImage: "hand.thumbsup")
                        }
                        Button { Task { try? await comment.downvote() } } label: {
                            Label("Downvote", systemImage: "hand.thumbsdown")
                        }
                    } else {
                        Button { Task { try? await comment.unvote() } } label: {
                            Label("Unvote", systemImage: "arrow.uturn.backward")
                        }
                    }
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
