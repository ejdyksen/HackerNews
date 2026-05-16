// Story row views for feed lists and split-view selections. This file formats
// story metadata compactly and exposes the row-level voting context menu.
import SwiftUI

struct ListingItemCellContent: View {
    @ObservedObject var item: HNItem
    var isSelected: Bool = false
    var leadingInset: CGFloat = 0

    private var secondaryStyle: Color {
        isSelected ? Color.white.opacity(0.85) : Color.secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleWithDomain
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            metadataText
                .font(.footnote)
                .foregroundStyle(secondaryStyle)
                .lineLimit(1)
                .padding(.top, 6)
        }
        .padding(.leading, leadingInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(accessibilityMetadata)
        .accessibilityHint("Opens the discussion")
        .storyVoteAccessibilityActions(for: item)
        .contextMenu {
            ShareLink(
                item: item.shareLink,
                preview: SharePreview(item.title)
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            if item.canUpvote {
                if !item.isUpvoted && !item.isDownvoted {
                    Button { Task { try? await item.upvote() } } label: {
                        Label("Upvote", systemImage: "hand.thumbsup")
                    }
                    if item.canDownvote {
                        Button { Task { try? await item.downvote() } } label: {
                            Label("Downvote", systemImage: "hand.thumbsdown")
                        }
                    }
                } else {
                    Button { Task { try? await item.unvote() } } label: {
                        Label("Unvote", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!item.canResetVote)
                }
            }
        }
    }

    private var titleWithDomain: Text {
        let title = Text(item.title)
            .font(.headline)
        guard !item.domain.isEmpty else { return title }
        let domain = Text(" (\(item.domain))")
            .font(.caption)
            .foregroundStyle(secondaryStyle)
        return Text("\(title)\(domain)")
    }

    private var metadataText: Text {
        var pieces: [Text] = []

        if let score = item.score {
            if item.isUpvoted {
                pieces.append(
                    Text(
                        "\(Text(Image(systemName: "hand.thumbsup.fill")).foregroundStyle(.orange)) \(score) pts"
                    )
                )
            } else {
                pieces.append(Text("\(score) pts"))
            }
        }
        if let author = item.author { pieces.append(Text("by \(author)")) }
        if let age = item.age { pieces.append(Text(relativeTimeString(from: age, style: .short))) }
        pieces.append(Text("· \(item.commentCount) comments"))

        var result = pieces.first ?? Text("")
        for piece in pieces.dropFirst() {
            result = Text("\(result) \(piece)")
        }
        return result
    }

    private var accessibilityTitle: String {
        if item.domain.isEmpty {
            return item.title
        }
        return "\(item.title), \(item.domain)"
    }

    private var accessibilityMetadata: String {
        var pieces: [String] = []

        if let score = item.score {
            pieces.append("\(score) \(score == 1 ? "point" : "points")")
        }

        if item.isUpvoted {
            pieces.append("upvoted")
        } else if item.isDownvoted {
            pieces.append("downvoted")
        }

        if let author = item.author, !author.isEmpty {
            pieces.append("by \(author)")
        }

        if let age = item.age {
            pieces.append(relativeTimeString(from: age))
        }

        pieces.append("\(item.commentCount) \(item.commentCount == 1 ? "comment" : "comments")")
        return pieces.joined(separator: ", ")
    }
}

struct ListingItemCell: View {
    @ObservedObject var item: HNItem
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ListingItemCellContent(item: item)
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    @ViewBuilder
    func storyVoteAccessibilityActions(for item: HNItem) -> some View {
        if item.canUpvote, item.canDownvote, !item.isUpvoted, !item.isDownvoted {
            self
                .accessibilityAction(named: Text("Upvote story")) {
                    Task { try? await item.upvote() }
                }
                .accessibilityAction(named: Text("Downvote story")) {
                    Task { try? await item.downvote() }
                }
        } else if item.canUpvote, !item.isUpvoted, !item.isDownvoted {
            self.accessibilityAction(named: Text("Upvote story")) {
                Task { try? await item.upvote() }
            }
        } else if item.canResetVote, item.isUpvoted || item.isDownvoted {
            self.accessibilityAction(named: Text("Unvote story")) {
                Task { try? await item.unvote() }
            }
        } else {
            self
        }
    }
}

#if DEBUG
struct ListingItemCellContent_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ListingItemCellContent(item: itemOne)
                .previewLayout(.sizeThatFits)
                .padding()
            ListingItemCell(item: itemOne, onSelect: {})
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
#endif
