import Foundation
import Fuzi
import SwiftUI

@MainActor class HNItem: ObservableObject, Identifiable, Hashable, Equatable {
    let id: Int
    var title: String
    var storyLink: URL
    var domain: String

    private var currentPage = 1
    var canLoadMore = true

    var age: Date?
    var author: String?

    var score: Int?
    var commentCount: Int

    @Published var isLoading = false
    @Published var loadError: String?
    @Published var rootComments: [HNComment] = []
    @Published var flatComments: [HNComment] = []
    @Published var body: AttributedString? = nil
    @Published private(set) var lastUpdated: Date?

    private var upvoteAuth: String?
    private var downvoteAuth: String?
    @Published var isUpvoted: Bool = false
    @Published var isDownvoted: Bool = false

    var canUpvote: Bool { upvoteAuth != nil }
    var canDownvote: Bool { downvoteAuth != nil }

    func setVoteAuth(upvoteAuth: String?, downvoteAuth: String?) {
        self.upvoteAuth = upvoteAuth
        self.downvoteAuth = downvoteAuth
    }

    func upvote() async throws {
        guard let auth = upvoteAuth else { return }
        let voteEndpoint = "https://news.ycombinator.com/vote?id=\(id)&how=up&auth=\(auth)&goto=item%3Fid%3D\(id)&js=t"
        _ = try await RequestController.shared.makeRequest(endpoint: voteEndpoint)
        isUpvoted = true
        isDownvoted = false
    }

    func downvote() async throws {
        guard let auth = downvoteAuth else { return }
        let voteEndpoint = "https://news.ycombinator.com/vote?id=\(id)&how=down&auth=\(auth)&goto=item%3Fid%3D\(id)&js=t"
        _ = try await RequestController.shared.makeRequest(endpoint: voteEndpoint)
        isDownvoted = true
        isUpvoted = false
    }

    func unvote() async throws {
        guard let auth = isUpvoted ? upvoteAuth : downvoteAuth else { return }
        let voteEndpoint = "https://news.ycombinator.com/vote?id=\(id)&how=un&auth=\(auth)&goto=item%3Fid%3D\(id)&js=t"
        _ = try await RequestController.shared.makeRequest(endpoint: voteEndpoint)
        isUpvoted = false
        isDownvoted = false
    }

    @MainActor private static func buildFlatComments(_ root: [HNComment]) -> [HNComment] {
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
        return URL(string: "https://news.ycombinator.com/item?id=\(self.id)")!
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

    nonisolated init(id: Int, title: String, storyLink: URL, domain: String, age: Date, author: String, score: Int?, commentCount: Int?) {
        self.id = id
        self.title = title
        self.storyLink = storyLink
        self.domain = domain
        self.age = age
        self.author = author
        self.score = score ?? 0
        self.commentCount = commentCount ?? 0
    }

    init?(withXmlNode node: Fuzi.XMLElement) {
        // Gather some additional XMLNodes
        guard
            let adjacentItem = node.firstChild(xpath: "./following-sibling::tr[1]"),
            let storyLinkNode = node.firstChild(xpath: ".//*[@class='titleline']//a")
        else {
            return nil
        }

        // Get an item ID, which is required
        guard let idString = node.attributes["id"], let id = Int(idString) else {
            return nil
        }
        self.id = id

        // Link and title, which are required
        guard let href = storyLinkNode.attributes["href"] else { return nil }
        let storyLink: URL
        if href.hasPrefix("http://") || href.hasPrefix("https://") {
            guard let url = URL(string: href) else { return nil }
            storyLink = url
        } else {
            guard let url = URL(string: "https://news.ycombinator.com/\(href)") else { return nil }
            storyLink = url
        }
        self.storyLink = storyLink
        self.title = storyLinkNode.stringValue

        if let domainNode = node.firstChild(css: ".sitestr")  {
            self.domain = domainNode.stringValue
        } else {
            self.domain = ""
        }

        // Age, required — parsed from the `.age` span's `title` attribute
        guard let ageNode = adjacentItem.firstChild(css: ".age"),
              let age = hnDate(fromAge: ageNode) else {
            return nil
        }
        self.age = age


        // Score, optional
        if
            let scoreString = adjacentItem.firstChild(css: ".score")?.stringValue,
            let scoreStringComponent = scoreString.split(separator: " ").first,
            let score = Int(scoreStringComponent) {
            self.score = score
        } else {
            self.score = nil
        }

        // Author, optional
        self.author = adjacentItem.firstChild(css: ".hnuser")?.stringValue

        // Comment count, optional
        if let commentString = adjacentItem.firstChild(xpath: ".//a[contains(text(), 'comment') or text()='discuss']")?.stringValue {
            if commentString == "discuss" {
                self.commentCount = 0
            } else {
                // Parse "N comments" — use prefix scan to handle &nbsp; between number and word
                let digits = commentString.prefix(while: { $0.isNumber })
                self.commentCount = digits.isEmpty ? 0 : (Int(digits) ?? 0)
            }
        } else {
            self.commentCount = 0
        }

        if let upvoteLink = node.firstChild(css: "#up_\(id)")?.attr("href"),
           let upvoteUrl = URL(string: "https://news.ycombinator.com/\(upvoteLink)"),
           let components = URLComponents(url: upvoteUrl, resolvingAgainstBaseURL: false),
           let auth = components.queryItems?.first(where: { $0.name == "auth" })?.value {
            self.upvoteAuth = auth
        }

        if let downvoteLink = node.firstChild(css: "#down_\(id)")?.attr("href"),
           let downvoteUrl = URL(string: "https://news.ycombinator.com/\(downvoteLink)"),
           let components = URLComponents(url: downvoteUrl, resolvingAgainstBaseURL: false),
           let auth = components.queryItems?.first(where: { $0.name == "auth" })?.value {
            self.downvoteAuth = auth
        }

        if let unvoteNode = adjacentItem.firstChild(css: "#un_\(id)") {
            if unvoteNode.stringValue.lowercased() == "undown" {
                self.isDownvoted = true
            } else {
                self.isUpvoted = true
            }
        }
    }


    nonisolated static func == (lhs: HNItem, rhs: HNItem) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func updateMetadata(from other: HNItem) {
        self.objectWillChange.send()
        self.title = other.title
        self.storyLink = other.storyLink
        self.domain = other.domain
        self.age = other.age
        if let author = other.author { self.author = author }
        if let score = other.score { self.score = score }
        if other.commentCount > 0 { self.commentCount = other.commentCount }
        self.upvoteAuth = other.upvoteAuth
        self.downvoteAuth = other.downvoteAuth
        self.isUpvoted = other.isUpvoted
        self.isDownvoted = other.isDownvoted
    }

    func refreshIfStale() {
        if case .stale = Freshness(for: lastUpdated) {
            debugLog("item/\(id)", "stale -> refresh")
            loadMoreContent(reload: true)
        }
    }

    func refreshIfOlderThan(_ threshold: TimeInterval) {
        guard let lastUpdated else { return }
        let age = Date.now.timeIntervalSince(lastUpdated)
        if age > threshold {
            debugLog("item/\(id)", "nav refresh: age=\(Int(age))s > \(Int(threshold))s")
            loadMoreContent(reload: true)
        }
    }

    func loadMoreContent(reload: Bool = false) async {
        await withCheckedContinuation { continuation in
            loadMoreContent(reload: reload) { continuation.resume() }
        }
    }

    func loadMoreContent(reload: Bool = false, completion: (() -> Void)? = nil) {
        if reload {
            currentPage = 1
            canLoadMore = true
            rootComments = []
            flatComments = []
            body = nil
            loadError = nil
        }
        isLoading = true
        let page = currentPage
        Task {
            do {
                let url = "https://news.ycombinator.com/item?id=\(self.id)&p=\(page)"
                let doc = try await RequestController.shared.makeRequest(endpoint: url)

                if let fatRow = doc.css("table.fatitem tr.athing").first,
                   let stub = HNItem(withXmlNode: fatRow) {
                    // Populate metadata from fatitem when navigated via deep link (title is empty)
                    if self.title.isEmpty {
                        self.objectWillChange.send()
                        self.title = stub.title
                        self.storyLink = stub.storyLink
                        self.domain = stub.domain
                        self.age = stub.age
                        self.author = stub.author
                        if let s = stub.score { self.score = s }
                        self.commentCount = stub.commentCount
                    }
                    // Always refresh vote auth and state — listing-fetched ones may be stale
                    self.setVoteAuth(upvoteAuth: stub.upvoteAuth, downvoteAuth: stub.downvoteAuth)
                    self.isUpvoted = stub.isUpvoted
                    self.isDownvoted = stub.isDownvoted
                }

                let parsedBody: AttributedString? = doc.css("table.fatitem .commtext").first
                    .map { HNComment.parseText($0) }
                    .flatMap { $0.characters.isEmpty ? nil : $0 }

                let nodeList = doc.css("table.comment-tree tr.athing")
                let newComments = HNComment.createCommentTree(nodes: nodeList)
                let canLoadMoreValue = !doc.css(".morelink").isEmpty

                let updatedRoot = self.rootComments + newComments
                self.rootComments = updatedRoot
                self.flatComments = Self.buildFlatComments(updatedRoot)
                self.body = parsedBody
                self.canLoadMore = canLoadMoreValue
                if page == 1 {
                    self.lastUpdated = .now
                    debugLog("item/\(self.id)", "loaded \(self.flatComments.count) comments\(reload ? " (reload)" : "")")
                }
                self.currentPage = page + 1
                self.isLoading = false
                self.loadError = nil
                completion?()
            } catch {
                self.isLoading = false
                self.loadError = error.localizedDescription
                debugLog("item/\(self.id)", "load error: \(error.localizedDescription)")
                completion?()
            }
        }
    }
}
