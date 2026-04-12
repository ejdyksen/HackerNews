import SwiftUI

struct ItemDetailHeader: View {
    @ObservedObject var item: HNItem
    @Environment(\.openURL) private var openURL

    private var isSelfLink: Bool {
        item.storyLink.absoluteString == item.itemLink.absoluteString
    }

    private var subheadingText: Text {
        var pieces: [Text] = []

        if let score = item.score {
            if item.isUpvoted {
                pieces.append(
                    Text(Image(systemName: "hand.thumbsup.fill")).foregroundColor(.orange)
                    + Text(" \(score) points")
                )
            } else {
                pieces.append(Text("\(score) points"))
            }
        }
        if let author = item.author { pieces.append(Text("by \(author)")) }
        if let age = item.age { pieces.append(Text(relativeTimeString(from: age))) }

        var result = pieces.first ?? Text("")
        for piece in pieces.dropFirst() {
            result = result + Text(" ") + piece
        }
        return result
    }

    private var titleWithDomain: Text {
        let title = Text(item.title)
            .font(.title2)
            .foregroundStyle(.primary)
        guard !item.domain.isEmpty else { return title }
        let domain = Text("(\(item.domain))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        return Text("\(title) \(domain)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            if isSelfLink {
                titleWithDomain
                    .multilineTextAlignment(.leading)
            } else {
                Button { openURL(item.storyLink) } label: {
                    titleWithDomain
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }

            subheadingText
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            if let body = item.body {
                Text(body)

                Divider()
            }
        }
    }
}

struct ItemDetailHeader_Previews: PreviewProvider {
    static var previews: some View {
        ItemDetailHeader(item: HNItem.itemWithComments())
    }
}
