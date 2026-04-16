// Observable story state. This model owns one item's metadata, comment pages,
// and in-flight loading state after parsed data has been fetched elsewhere.
import Foundation
import SwiftUI

@MainActor final class HNItem: ObservableObject, Identifiable, Hashable, Equatable {
    let id: Int
    var title: String
    var storyLink: URL
    var domain: String

    var age: Date?
    var author: String?

    var score: Int?
    var commentCount: Int

    @Published var isLoading = false
    @Published var loadError: String?
    @Published var rootComments: [HNComment] = []
    @Published var flatComments: [HNComment] = []
    @Published var body: AttributedString?
    @Published private(set) var lastUpdated: Date?

    private var upvoteAuth: String?
    private var downvoteAuth: String?
    @Published var isUpvoted = false
    @Published var isDownvoted = false
    @Published var canResetVote = false

    private var loadTask: Task<Void, Never>?
    private var activeLoadID: UUID?

    var canUpvote: Bool { upvoteAuth != nil }
    var canDownvote: Bool { downvoteAuth != nil }

    func setVoteAuth(upvoteAuth: String?, downvoteAuth: String?) {
        self.upvoteAuth = upvoteAuth
        self.downvoteAuth = downvoteAuth
    }

    func upvote() async throws {
        guard let auth = upvoteAuth else { return }
        try await HNRepository.shared.submitVote(itemID: id, action: .up, auth: auth)
        isUpvoted = true
        isDownvoted = false
        canResetVote = true
    }

    func downvote() async throws {
        guard let auth = downvoteAuth else { return }
        try await HNRepository.shared.submitVote(itemID: id, action: .down, auth: auth)
        isDownvoted = true
        isUpvoted = false
        canResetVote = true
    }

    func unvote() async throws {
        guard let auth = isUpvoted ? upvoteAuth : downvoteAuth else { return }
        try await HNRepository.shared.submitVote(itemID: id, action: .un, auth: auth)
        isUpvoted = false
        isDownvoted = false
        canResetVote = false
    }

    private static func buildFlatComments(_ root: [HNComment]) -> [HNComment] {
        var result: [HNComment] = []

        func traverse(_ comments: [HNComment]) {
            for comment in comments {
                result.append(comment)
                traverse(comment.children)
            }
        }

        traverse(root)
        return result
    }

    var itemLink: URL {
        URL(string: "https://news.ycombinator.com/item?id=\(id)")!
    }

    var shareLink: URL {
        storyLink.absoluteString == itemLink.absoluteString ? itemLink : storyLink
    }

    var subheading: String {
        var parts: [String] = []
        if let score { parts.append("\(score) points") }
        if let author { parts.append("by \(author)") }
        if let age { parts.append(relativeTimeString(from: age)) }
        return parts.joined(separator: " ")
    }

    nonisolated init(id: Int) {
        self.id = id
        self.title = ""
        self.storyLink = URL(string: "https://news.ycombinator.com/item?id=\(id)")!
        self.domain = ""
        self.age = nil
        self.author = nil
        self.score = nil
        self.commentCount = 0
    }

    nonisolated init(
        id: Int,
        title: String,
        storyLink: URL,
        domain: String,
        age: Date,
        author: String,
        score: Int?,
        commentCount: Int?
    ) {
        self.id = id
        self.title = title
        self.storyLink = storyLink
        self.domain = domain
        self.age = age
        self.author = author
        self.score = score ?? 0
        self.commentCount = commentCount ?? 0
    }

    convenience init(parsed: ParsedHNItem) {
        self.init(id: parsed.id)
        updateMetadata(from: parsed)
    }

    nonisolated static func == (lhs: HNItem, rhs: HNItem) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func updateMetadata(from parsed: ParsedHNItem) {
        objectWillChange.send()
        title = parsed.title
        storyLink = parsed.storyLink
        domain = parsed.domain
        age = parsed.age
        if let author = parsed.author { self.author = author }
        if let score = parsed.score { self.score = score }
        commentCount = parsed.commentCount
        upvoteAuth = parsed.voteState.upvoteAuth
        downvoteAuth = parsed.voteState.downvoteAuth
        isUpvoted = parsed.voteState.isUpvoted
        isDownvoted = parsed.voteState.isDownvoted
        canResetVote = parsed.voteState.canResetVote
    }

    func loadMoreContent(reload: Bool = false) async {
        await startLoad(reload: reload).value
    }

    func loadMoreContent(reload: Bool = false) {
        _ = startLoad(reload: reload)
    }

    // Called at navigation events (tap / deep link): ensures the user lands on
    // either fresh cached content or a spinner-covered fetch. Fresh cached
    // content stays untouched; stale content is cleared so the detail view's
    // existing `isLoading && flatComments.isEmpty` spinner overlay fires.
    // Metadata (title / score / vote state) is preserved since it comes from
    // the listing parse and should stay visible during the reload.
    func loadIfStaleOrMissing() {
        if isLoading { return }
        guard Freshness(for: lastUpdated) != .fresh else { return }

        if lastUpdated != nil {
            rootComments = []
            flatComments = []
            body = nil
            lastUpdated = nil
        }
        loadMoreContent()
    }

    @discardableResult
    private func startLoad(reload: Bool) -> Task<Void, Never> {
        if reload {
            loadTask?.cancel()
            loadTask = nil
        } else if let loadTask {
            return loadTask
        }

        // Non-reload calls after a successful load are no-ops. HN serves the
        // entire comment thread on a single page, so there's nothing to fetch
        // unless the caller explicitly asks to reload.
        if !reload && lastUpdated != nil {
            return Task {}
        }

        isLoading = true
        loadError = nil

        // Reloads keep the existing rootComments / flatComments / body until
        // the new response lands in `finishLoad`. That way a failing reload
        // leaves the user reading the previously loaded thread instead of
        // staring at an empty error screen.
        let loadID = UUID()
        activeLoadID = loadID

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let pageData = try await HNRepository.shared.fetchItemPage(itemID: self.id)
                self.finishLoad(
                    loadID: loadID,
                    reload: reload,
                    result: .success(pageData)
                )
            } catch is CancellationError {
                self.finishCancellation(loadID: loadID)
            } catch {
                self.finishLoad(
                    loadID: loadID,
                    reload: reload,
                    result: .failure(error)
                )
            }
        }

        loadTask = task
        return task
    }

    private func finishLoad(
        loadID: UUID,
        reload: Bool,
        result: Result<ParsedHNItemPage, Error>
    ) {
        guard activeLoadID == loadID else { return }

        defer {
            loadTask = nil
            isLoading = false
        }

        switch result {
        case .success(let pageData):
            if let metadata = pageData.metadata {
                updateMetadata(from: metadata)
            }

            let newRootComments = PerfLog.measure(PerfLog.models, "buildModels") {
                HNComment.models(from: pageData.rootComments)
            }

            PerfLog.measure(PerfLog.models, "applyToMain") {
                rootComments = newRootComments
                flatComments = PerfLog.measure(PerfLog.models, "flatten") {
                    Self.buildFlatComments(newRootComments)
                }
                body = pageData.body
                loadError = nil
            }

            lastUpdated = .now
            debugLog(
                "item/\(id)",
                "loaded \(flatComments.count) comments\(reload ? " (reload)" : "")"
            )

        case .failure(let error):
            loadError = error.localizedDescription
            debugLog("item/\(id)", "load error: \(error.localizedDescription)")
        }
    }

    private func finishCancellation(loadID: UUID) {
        guard activeLoadID == loadID else { return }
        loadTask = nil
        isLoading = false
    }
}
