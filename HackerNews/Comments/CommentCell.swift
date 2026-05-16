// Row rendering for one flattened comment in the thread view. This handles the
// collapse gesture, indentation, and per-comment vote actions.
import SwiftUI

struct CommentCell: View {
    static let contentHorizontalPadding: CGFloat = 16
    static let indentStep: CGFloat = 12
    static let maxIndent: CGFloat = 72

    @ObservedObject var comment: HNComment
    let isCollapsed: Bool
    let onToggle: () -> Void
    var onCollapseToRoot: ((HNComment) -> Void)? = nil
    var onShowUserProfile: ((String) -> Void)? = nil

    private var leadingIndent: CGFloat {
        min(CGFloat(comment.indentLevel) * Self.indentStep, Self.maxIndent)
    }

    private var plainText: String {
        String(comment.content.characters)
    }

    private var collapsedPreviewText: String {
        let compact = plainText
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return compact
    }

    private var descendantCount: Int {
        countDescendants(of: comment)
    }

    private var accessibilityValueText: String {
        var pieces: [String] = [
            relativeTimeString(from: comment.age),
            "level \(comment.indentLevel + 1)"
        ]

        if comment.isUpvoted {
            pieces.append("upvoted")
        } else if comment.isDownvoted {
            pieces.append("downvoted")
        }

        if isCollapsed {
            pieces.append("collapsed")
            if descendantCount > 0 {
                let hiddenText = descendantCount == 1 ? "1 reply hidden" : "\(descendantCount) replies hidden"
                pieces.append(hiddenText)
            }
            pieces.append(collapsedPreviewText)
        } else {
            pieces.append(plainText)
        }

        return pieces.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    if comment.canUpvote {
                        voteStateIcon
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
            .padding(.horizontal, Self.contentHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onToggle()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Comment by \(comment.author)")
            .accessibilityValue(accessibilityValueText)
            .accessibilityHint(isCollapsed ? "Double tap to expand" : "Double tap to collapse")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onToggle()
                }
            }
            .accessibilityAction(named: Text(isCollapsed ? "Expand comment" : "Collapse comment")) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onToggle()
                }
            }
            .accessibilityAction(named: Text("Collapse thread to root")) {
                onCollapseToRoot?(comment)
            }
            .accessibilityAction(named: Text("View profile")) {
                onShowUserProfile?(comment.author)
            }
            .commentVoteAccessibilityActions(for: comment)
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
                            Label("Upvote", systemImage: "triangle.fill")
                        }
                        if comment.canDownvote {
                            Button { Task { try? await comment.downvote() } } label: {
                                Label("Downvote", systemImage: "hand.thumbsdown")
                            }
                        }
                    } else {
                        Button { Task { try? await comment.unvote() } } label: {
                            Label("Unvote", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(!comment.canResetVote)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var voteStateIcon: some View {
        Group {
            if comment.isUpvoted {
                Image(systemName: "triangle.fill")
                    .foregroundColor(.orange)
            } else if comment.isDownvoted {
                Image(systemName: "hand.thumbsdown.fill")
                    .foregroundColor(.gray)
            }
        }
        .font(.caption)
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }

    private func countDescendants(of comment: HNComment) -> Int {
        comment.children.reduce(comment.children.count) { total, child in
            total + countDescendants(of: child)
        }
    }
}

private extension View {
    @ViewBuilder
    func commentVoteAccessibilityActions(for comment: HNComment) -> some View {
        if comment.canUpvote, comment.canDownvote, !comment.isUpvoted, !comment.isDownvoted {
            self
                .accessibilityAction(named: Text("Upvote comment")) {
                    Task { try? await comment.upvote() }
                }
                .accessibilityAction(named: Text("Downvote comment")) {
                    Task { try? await comment.downvote() }
                }
        } else if comment.canUpvote, !comment.isUpvoted, !comment.isDownvoted {
            self.accessibilityAction(named: Text("Upvote comment")) {
                Task { try? await comment.upvote() }
            }
        } else if comment.canResetVote, comment.isUpvoted || comment.isDownvoted {
            self.accessibilityAction(named: Text("Unvote comment")) {
                Task { try? await comment.unvote() }
            }
        } else {
            self
        }
    }
}

#if DEBUG
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
#endif
