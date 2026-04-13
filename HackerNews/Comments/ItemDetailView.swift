// Story detail screen showing the story header plus a flattened comment thread.
// It owns local UI state like collapsed comments and scroll-position affordances.
import SwiftUI

struct ItemDetailView: View {
    @ObservedObject var item: HNItem
    @EnvironmentObject private var cache: AppCache
    @EnvironmentObject private var readState: ReadStateStore
    @State private var collapsedIDs: Set<Int> = []
    @State private var showScrolledTitle = false
    @State private var scrollPosition = ScrollPosition()
    var onShowUserProfile: ((String) -> Void)? = nil
    var onToggleFullScreen: (() -> Void)? = nil
    var isFullScreen: Bool = false
    private let readableContentWidth: CGFloat = 760

    private var safariURL: URL {
        item.shareLink
    }

    private var truncatedTitle: String {
        let maxChars = 35
        if item.title.count > maxChars {
            return String(item.title.prefix(maxChars - 1)) + "…"
        }
        return item.title
    }

    private var visibleComments: [HNComment] {
        var result: [HNComment] = []
        var hiddenBelowLevel: Int? = nil

        for comment in item.flatComments {
            if let hideLevel = hiddenBelowLevel {
                if comment.indentLevel > hideLevel {
                    continue
                } else {
                    hiddenBelowLevel = nil
                }
            }
            result.append(comment)
            if collapsedIDs.contains(comment.id) {
                hiddenBelowLevel = comment.indentLevel
            }
        }
        return result
    }

    private func collapseToRoot(for comment: HNComment) {
        guard let commentIndex = item.flatComments.firstIndex(where: { $0.id == comment.id }) else {
            return
        }

        let rootComment: HNComment
        if comment.indentLevel == 0 {
            rootComment = comment
        } else if let rootIndex = item.flatComments[..<commentIndex].lastIndex(where: { $0.indentLevel == 0 }) {
            rootComment = item.flatComments[rootIndex]
        } else {
            rootComment = comment
        }

        withAnimation(.easeInOut) {
            collapsedIDs.insert(rootComment.id)
        }
    }

    @ViewBuilder
    private var scrollContent: some View {
        ItemDetailHeader(item: item, onShowUserProfile: onShowUserProfile)
            .padding(.horizontal)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .scrollView).maxY
            } action: { maxY in
                let shouldShow = maxY < 0
                if shouldShow != showScrolledTitle {
                    withAnimation(.easeInOut) {
                        showScrolledTitle = shouldShow
                    }
                }
            }

        LazyVStack(spacing: 0) {
            ForEach(visibleComments) { comment in
                CommentCell(
                    comment: comment,
                    isCollapsed: collapsedIDs.contains(comment.id),
                    onToggle: {
                        if collapsedIDs.contains(comment.id) {
                            collapsedIDs.remove(comment.id)
                        } else {
                            collapsedIDs.insert(comment.id)
                        }
                    },
                    onCollapseToRoot: collapseToRoot(for:),
                    onShowUserProfile: onShowUserProfile
                )
            }
        }

        if let error = item.loadError {
            VStack(spacing: 12) {
                Text("Failed to load comments")
                    .foregroundColor(.secondary)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { item.loadMoreContent() }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else if item.canLoadMore {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .onAppear { item.loadMoreContent() }
        } else if item.flatComments.isEmpty {
            Text("No comments yet")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                scrollContent
            }
            .frame(maxWidth: readableContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let toggle = onToggleFullScreen {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: toggle) {
                        Image(systemName: isFullScreen
                            ? "arrow.down.right.and.arrow.up.left"
                            : "arrow.up.left.and.arrow.down.right")
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                if showScrolledTitle {
                    Button {
                        withAnimation {
                            scrollPosition.scrollTo(edge: .top)
                        }
                    } label: {
                        VStack(spacing: 1) {
                            Text(truncatedTitle)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(item.commentCount) comments")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(
                        item: item.shareLink,
                        preview: SharePreview(item.title)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        UIApplication.shared.open(safariURL)
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .scrollPosition($scrollPosition)
        .refreshable {
            await item.loadMoreContent(reload: true)
        }
        .onAppear {
            cache.rememberItem(item)
            readState.markRead(item.id)
            item.refreshIfOlderThan(Freshness.navigationRefreshThreshold)
        }
        .onForegroundActivation {
            item.refreshIfStale()
        }
        .lastUpdatedToast(item.lastUpdated, source: "item/\(item.id)")
    }
}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ItemDetailView(item: HNItem.itemWithComments())
                    .environmentObject(AppCache())
            }
        }
    }
}
