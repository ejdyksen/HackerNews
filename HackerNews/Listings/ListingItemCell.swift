// Story row views for feed lists and split-view selections. This file formats
// story metadata compactly and exposes the row-level voting context menu.
import SwiftUI

struct ListingItemCellContent: View {
    @ObservedObject var item: HNItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleWithDomain
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            metadataText
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
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
                }
            }
        }
    }

    private var titleWithDomain: Text {
        let title = Text(item.title)
            .font(.headline)
            .foregroundStyle(.primary)
        guard !item.domain.isEmpty else { return title }
        let domain = Text(" (\(item.domain))")
            .font(.caption)
            .foregroundStyle(.secondary)
        return Text("\(title)\(domain)")
    }

    private var metadataText: Text {
        var pieces: [Text] = []

        if let score = item.score {
            if item.isUpvoted {
                pieces.append(
                    Text(Image(systemName: "hand.thumbsup.fill")).foregroundColor(.orange)
                    + Text(" \(score) pts")
                )
            } else {
                pieces.append(Text("\(score) pts"))
            }
        }
        if let author = item.author { pieces.append(Text("by \(author)")) }
        if let age = item.age { pieces.append(Text(relativeTimeString(from: age))) }
        pieces.append(Text(" · \(item.commentCount) comments"))

        var result = pieces.first ?? Text("")
        for piece in pieces.dropFirst() {
            result = result + Text(" ") + piece
        }
        return result
    }
}

struct ListingItemCell: View {
    var item: HNItem

    var body: some View {
        NavigationLink(value: item) {
            ListingItemCellContent(item: item)
        }
    }
}

struct ListingItemCell_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ListingItemCell(item: itemOne)
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
