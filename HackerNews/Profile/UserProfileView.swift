// Native profile screen for a Hacker News user page, including basic metadata,
// rich-text about content, and links to the user's public HN pages.
import SwiftUI

struct UserProfileView: View {
    let route: HNUserRoute
    @EnvironmentObject private var cache: AppCache

    var body: some View {
        UserProfileViewBody(user: cache.user(for: route.username))
    }
}

private struct UserProfileViewBody: View {
    @ObservedObject var user: HNUser
    @Environment(\.openURL) private var openURL
    private let readableContentWidth: CGFloat = 680

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let error = user.loadError, user.createdText == nil, user.karma == nil {
                    ContentUnavailableView {
                        Label("Failed to Load", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { user.loadContent(reload: true) }
                    }
                } else {
                    profileContent
                }
            }
            .frame(maxWidth: readableContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
            .padding(.vertical, 20)
        }
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: user.username) {
            user.loadInitialContent()
            user.refreshIfStale()
        }
        .onForegroundActivation {
            user.refreshIfStale()
        }
        .overlay {
            if user.isLoading, user.createdText == nil, user.karma == nil {
                ProgressView("Loading...")
            }
        }
        .lastUpdatedToast(user.lastUpdated, source: "user/\(user.username)")
    }

    private var profileContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                profileRow(label: "user", value: user.displayName)

                if let createdText = user.createdText {
                    profileRow(label: "created", value: createdText)
                }

                if let karma = user.karma {
                    profileRow(label: "karma", value: "\(karma)")
                }
            }

            if let about = user.about {
                VStack(alignment: .leading, spacing: 8) {
                    Text("about")
                        .font(.headline)
                    Text(about)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            profileLinks
        }
    }

    private var profileLinks: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let submissionsURL = user.submissionsURL {
                Button("submissions") {
                    openURL(submissionsURL)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.accent)
            }

            if let commentsURL = user.commentsURL {
                Button("comments") {
                    openURL(commentsURL)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.accent)
            }

            if let favoritesURL = user.favoritesURL {
                Button("favorites") {
                    openURL(favoritesURL)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.accent)
            }
        }
    }

    private func profileRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(label):")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            UserProfileView(route: HNUserRoute(username: "patio11"))
                .environmentObject(AppCache())
        }
    }
}
