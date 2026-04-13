// Header content for a story detail screen, including the story title, metadata,
// and any self-post body content parsed from the Hacker News item page.
import SwiftUI

struct ItemDetailHeader: View {
    @ObservedObject var item: HNItem
    var onShowUserProfile: ((String) -> Void)? = nil
    @Environment(\.openURL) private var openURL

    private var isSelfLink: Bool {
        item.storyLink.absoluteString == item.itemLink.absoluteString
    }

    private var scoreText: Text? {
        guard let score = item.score else { return nil }
        if item.isUpvoted {
            return Text(
                "\(Text(Image(systemName: "hand.thumbsup.fill")).foregroundStyle(.orange)) \(score) pts"
            )
        }
        return Text("\(score) pts")
    }

    @ViewBuilder
    private var subheadingView: some View {
        HStack(spacing: 4) {
            if let scoreText {
                scoreText
            }

            if let author = item.author, !author.isEmpty {
                Text("by")

                if let onShowUserProfile {
                    Button {
                        onShowUserProfile(author)
                    } label: {
                        Text(author)
                            .foregroundStyle(.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(author)
                }
            }

            if let age = item.age {
                Text(relativeTimeString(from: age, style: .short))
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
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

            subheadingView

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
