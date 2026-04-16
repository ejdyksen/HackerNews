// Header content for a story detail screen, including the story title, metadata,
// and any self-post body content parsed from the Hacker News item page.
import SwiftUI

struct ItemDetailHeader: View {
    @ObservedObject var item: HNItem
    var onShowUserProfile: ((String) -> Void)? = nil
    @AppStorage("hideWebsitePreviews") private var hideWebsitePreviews = false
    @Environment(\.openURL) private var openURL

    private var isSelfLink: Bool {
        item.storyLink.absoluteString == item.itemLink.absoluteString
    }

    private var scoreText: Text? {
        guard let score = item.score else { return nil }
        if item.isUpvoted {
            return Text(
                "\(Text(Image(systemName: "hand.thumbsup.fill")).foregroundStyle(.orange)) \(score) points"
            )
        }
        return Text("\(score) points")
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
                Text(relativeTimeString(from: age))
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

    @ViewBuilder
    private var titleView: some View {
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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isSelfLink || hideWebsitePreviews {
                titleView
                subheadingView
            } else {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        titleView
                        subheadingView
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ExternalLinkPreviewView(url: item.storyLink)
                }
            }

            if let body = item.body {
                Text(body)
            }

            Divider()
        }
    }
}

#if DEBUG
struct ItemDetailHeader_Previews: PreviewProvider {
    static var previews: some View {
        ItemDetailHeader(item: HNItem.itemWithComments())
            .environmentObject(AppCache())
    }
}
#endif
