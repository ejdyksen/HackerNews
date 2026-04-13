// Row rendering for one flattened comment in the thread view. This handles the
// collapse gesture, indentation, and per-comment vote actions.
import SwiftUI

struct CommentCell: View {
    @ObservedObject var comment: HNComment
    let isCollapsed: Bool
    let onToggle: () -> Void
    var onCollapseToRoot: ((HNComment) -> Void)? = nil
    var onShowUserProfile: ((String) -> Void)? = nil
    private let indentStep: CGFloat = 12
    private let maxIndent: CGFloat = 72

    private var leadingIndent: CGFloat {
        min(CGFloat(comment.indentLevel) * indentStep, maxIndent)
    }

    private var collapsedPreviewText: String {
        let plainText = String(comment.content.characters)
        let compact = plainText
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    if isCollapsed {
                        Text(collapsedPreviewText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(relativeTimeString(from: comment.age, style: .short))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .lineLimit(1)
                .padding(.leading, leadingIndent)

                if !isCollapsed {
                    Text(comment.content)
                        .padding(.leading, leadingIndent)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onToggle()
                }
            }
            .contextMenu {
                Button {
                    onCollapseToRoot?(comment)
                } label: {
                    Label("Collapse to Root", systemImage: "arrow.up.to.line")
                }

                if !comment.author.isEmpty {
                    Button {
                        onShowUserProfile?(comment.author)
                    } label: {
                        Label("View Profile", systemImage: "person.crop.circle")
                    }
                }

                ShareLink(
                    item: comment.itemLink,
                    preview: SharePreview(comment.shareTitle)
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

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
                        .disabled(!comment.canResetVote)
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
