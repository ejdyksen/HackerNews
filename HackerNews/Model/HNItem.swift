import Foundation
import Fuzi
import SwiftUI

@MainActor class HNItem: ObservableObject, Identifiable, Hashable, Equatable {
    let id: Int
    let title: String
    let storyLink: URL
    let domain: String

    private var currentPage = 1
    var canLoadMore = true

    var domainString: String {
        if (self.domain == "") {
            return ""
        } else {
            return "  (\(self.domain))"
        }
    }

    let age: String
    let author: String?

    var score: Int?
    var commentCount: Int

    @Published var isLoading = false
    @Published var loadError: String?
    @Published var rootComments: [HNComment] = []
    @Published var flatComments: [HNComment] = []
    @Published var body: AttributedString? = nil

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
        if (score != nil && author != nil) {
            return "\(score!) points by \(author!) \(age)"
        } else if (score == nil && author != nil) {
            return "by \(author!) \(age)"
        } else if (score != nil && author == nil) {
            return "\(score!) points \(age)"
        } else {
            return age
        }
    }

    nonisolated init(id: Int, title: String, storyLink: URL, domain: String, age: String, author: String, score: Int?, commentCount: Int?) {
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

        // Age, required
        guard let ageNode = adjacentItem.firstChild(css: ".age") else {
            return nil
        }
        self.age = ageNode.stringValue


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
    }


    nonisolated static func == (lhs: HNItem, rhs: HNItem) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }

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
                self.currentPage = page + 1
                self.isLoading = false
                self.loadError = nil
                completion?()
            } catch {
                self.isLoading = false
                self.loadError = error.localizedDescription
                completion?()
            }
        }
    }
}
