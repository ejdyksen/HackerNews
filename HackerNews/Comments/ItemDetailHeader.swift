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
                    .accessibilityLabel("View profile for \(author)")
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
            .accessibilityLabel("Open story: \(item.title)")
            .accessibilityHint(item.domain.isEmpty ? "Opens the story link" : "Opens the story link from \(item.domain)")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            summaryView
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityTitle)
                .accessibilityValue(accessibilityMetadata)
                .accessibilityAddTraits(.isHeader)
                .itemHeaderAccessibilityActions(
                    isSelfLink: isSelfLink,
                    author: item.author,
                    openStory: { openURL(item.storyLink) },
                    showProfile: onShowUserProfile
                )

            if let body = item.body {
                Text(body)
            }

            Divider()
        }
    }

    @ViewBuilder
    private var summaryView: some View {
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
    }
}

private extension View {
    @ViewBuilder
    func itemHeaderAccessibilityActions(
        isSelfLink: Bool,
        author: String?,
        openStory: @escaping () -> Void,
        showProfile: ((String) -> Void)?
    ) -> some View {
        if !isSelfLink, let author, !author.isEmpty, let showProfile {
            self
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Actions available")
                .accessibilityAction {
                    openStory()
                }
                .accessibilityAction(named: Text("Open story")) {
                    openStory()
                }
                .accessibilityAction(named: Text("View profile for \(author)")) {
                    showProfile(author)
                }
        } else if !isSelfLink {
            self
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Actions available")
                .accessibilityAction {
                    openStory()
                }
                .accessibilityAction(named: Text("Open story")) {
                    openStory()
                }
        } else if let author, !author.isEmpty, let showProfile {
            self
                .accessibilityHint("Actions available")
                .accessibilityAction(named: Text("View profile for \(author)")) {
                    showProfile(author)
                }
        } else {
            self
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
