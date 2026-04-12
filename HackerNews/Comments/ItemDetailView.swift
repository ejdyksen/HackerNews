import SwiftUI

struct ItemDetailView: View {
    @ObservedObject var item: HNItem
    @State private var collapsedIDs: Set<Int> = []

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ItemDetailHeader(item: item)
                    .padding(.horizontal)

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
                            }
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
                    HStack(alignment: .center, spacing: 10) {
                        ProgressView()
                        Text("Loading").foregroundColor(.secondary)
                    }
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
        }
        .navigationTitle("\(item.commentCount) comments")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: URL.self) { url in
            WebView(url: url)
        }
        .refreshable {
            await withCheckedContinuation { continuation in
                item.loadMoreContent(reload: true) {
                    continuation.resume()
                }
            }
        }
    }
}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ItemDetailView(item: HNItem.itemWithComments())
            }
        }
    }
}
