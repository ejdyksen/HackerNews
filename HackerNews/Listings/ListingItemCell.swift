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
}

// Button-based (not NavigationLink) so the tap action runs synchronously
// *before* SwiftUI starts the push animation. The parent's `onSelect`
// closure fires `item.loadMoreContent()` in-line, getting URLSession
// into the queue ~200-400 ms earlier than waiting for
// `ItemDetailView.onAppear`.
//
// TODO(iOS 27+): This is a workaround for an iOS 26 gesture-recognizer
// regression that broke NavigationLink(value:) + .simultaneousGesture.
// See AGENTS.md "Listing Rows" for the simpler shape to revert to when
// a future iOS fixes it, and drop the onSelect closure threading.
struct ListingItemCell: View {
    var item: HNItem
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ListingItemCellContent(item: item)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
struct ListingItemCell_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ListingItemCell(item: itemOne, onSelect: {})
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
#endif
