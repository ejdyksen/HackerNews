// HTML parsing for Hacker News pages. This file turns Fuzi documents into
// lightweight parsed DTOs so models do not scrape DOM nodes directly.
import Foundation
import Fuzi
import SwiftUI

struct ParsedHNVoteState: Sendable {
    let upvoteAuth: String?
    let downvoteAuth: String?
    let isUpvoted: Bool
    let isDownvoted: Bool
    let canResetVote: Bool
}

struct ParsedHNItem: Sendable {
    let id: Int
    let title: String
    let storyLink: URL
    let domain: String
    let age: Date?
    let author: String?
    let score: Int?
    let commentCount: Int
    let voteState: ParsedHNVoteState
}

struct ParsedHNComment: Sendable {
    let id: Int
    let author: String
    let age: Date
    let indentLevel: Int
    let content: AttributedString
    let voteState: ParsedHNVoteState
    var children: [ParsedHNComment] = []
}

struct ParsedHNListingPage: Sendable {
    let items: [ParsedHNItem]
    let nextPageURL: String?
}

struct ParsedHNItemPage: Sendable {
    let metadata: ParsedHNItem?
    let body: AttributedString?
    let rootComments: [ParsedHNComment]
    let hasMoreContent: Bool
}

struct ParsedHNUserPage: Sendable {
    let username: String
    let createdText: String?
    let karma: Int?
    let about: AttributedString?
    let submissionsURL: URL?
    let commentsURL: URL?
    let favoritesURL: URL?
}

enum HNParsingError: Error {
    case htmlParseError(Error)
    case missingUserProfile
}

extension HNParsingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .htmlParseError:
            return "Couldn't read the page content. HN may have changed its layout."
        case .missingUserProfile:
            return "Couldn't find that Hacker News user."
        }
    }
}

enum HNHTMLParser {
    static func parseListingPage(
        data: Data,
        baseURLString: String
    ) throws -> ParsedHNListingPage {
        let doc = try document(from: data)
        let items = doc.css("tr.athing").compactMap(parseItem)
        let nextPageURL = parseMoreLink(doc: doc, baseURLString: baseURLString)
        return ParsedHNListingPage(items: items, nextPageURL: nextPageURL)
    }

    static func parseItemPage(data: Data) throws -> ParsedHNItemPage {
        let doc = try document(from: data)

        let metadata = doc.css("table.fatitem tr.athing").first.flatMap(parseItem)
        let body = doc.css("table.fatitem .commtext").first
            .map(parseCommentText)
            .flatMap { $0.characters.isEmpty ? nil : $0 }
        let rootComments = createCommentTree(nodes: doc.css("table.comment-tree tr.athing"))
        let hasMoreContent = !doc.css(".morelink").isEmpty

        return ParsedHNItemPage(
            metadata: metadata,
            body: body,
            rootComments: rootComments,
            hasMoreContent: hasMoreContent
        )
    }

    static func parseUserPage(data: Data) throws -> ParsedHNUserPage {
        let doc = try document(from: data)

        guard
            let usernameNode = doc.firstChild(
                xpath: "//tr[@id='bigbox']//tr[td[1][normalize-space()='user:']]/td[2]//*[@class='hnuser']"
            )
        else {
            throw HNParsingError.missingUserProfile
        }

        let username = usernameNode.stringValue
        let createdText = doc.firstChild(
            xpath: "//tr[@id='bigbox']//tr[td[1][normalize-space()='created:']]/td[2]"
        )?.stringValue
        let karmaText = doc.firstChild(
            xpath: "//tr[@id='bigbox']//tr[td[1][normalize-space()='karma:']]/td[2]"
        )?.stringValue
        let aboutNode = doc.firstChild(
            xpath: "//tr[@id='bigbox']//tr[td[1][normalize-space()='about:']]/td[2]"
        )

        let about = aboutNode
            .map { parseRichText($0, baseURL: URL(string: "https://news.ycombinator.com/")) }
            .flatMap { $0.characters.isEmpty ? nil : $0 }

        return ParsedHNUserPage(
            username: username,
            createdText: createdText,
            karma: karmaText.flatMap(Int.init),
            about: about,
            submissionsURL: resolvedHNURL(
                from: doc.firstChild(xpath: "//tr[@id='bigbox']//a[contains(@href, 'submitted?id=')]")?.attr("href")
            ),
            commentsURL: resolvedHNURL(
                from: doc.firstChild(xpath: "//tr[@id='bigbox']//a[contains(@href, 'threads?id=')]")?.attr("href")
            ),
            favoritesURL: resolvedHNURL(
                from: doc.firstChild(xpath: "//tr[@id='bigbox']//a[contains(@href, 'favorites?id=')]")?.attr("href")
            )
        )
    }

    static func parseCommentText(_ node: XMLElement) -> AttributedString {
        parseRichText(node)
    }

    static func parseRichText(_ node: XMLElement, baseURL: URL? = nil) -> AttributedString {
        var result = AttributedString()

        for child in node.childNodes(ofTypes: [.Element, .Text]) {
            if child.type == .Text {
                result += AttributedString(child.stringValue)
                continue
            }

            guard let element = child as? XMLElement else { continue }

            switch element.tag {
            case "p":
                if !result.characters.isEmpty {
                    result += AttributedString("\n\n")
                }
                result += parseRichText(element, baseURL: baseURL)
            case "i":
                var italic = parseRichText(element, baseURL: baseURL)
                italic.font = .italicSystemFont(ofSize: UIFont.systemFontSize)
                result += italic
            case "pre", "code":
                if !result.characters.isEmpty {
                    result += AttributedString("\n\n")
                }
                var code = AttributedString(element.stringValue)
                code.font = .monospacedSystemFont(
                    ofSize: UIFont.systemFontSize,
                    weight: .regular
                )
                result += code
            case "a":
                let href = element.attr("href") ?? ""
                var displayURL = href
                if displayURL.count > 50 {
                    displayURL = String(displayURL.prefix(47)) + "..."
                }

                var link = AttributedString(displayURL)
                if let url = resolvedURL(from: href, baseURL: baseURL) {
                    link.link = url
                }
                link.foregroundColor = .blue
                result += link
            default:
                result += parseRichText(element, baseURL: baseURL)
            }
        }

        return result
    }

    private static func document(from data: Data) throws -> HTMLDocument {
        do {
            return try HTMLDocument(data: data)
        } catch {
            throw HNParsingError.htmlParseError(error)
        }
    }

    private static func parseItem(_ node: XMLElement) -> ParsedHNItem? {
        guard
            let adjacentItem = node.firstChild(xpath: "./following-sibling::tr[1]"),
            let storyLinkNode = node.firstChild(xpath: ".//*[@class='titleline']//a"),
            let idString = node.attributes["id"],
            let id = Int(idString),
            let href = storyLinkNode.attributes["href"],
            let storyLink = resolvedStoryURL(from: href)
        else {
            return nil
        }

        let domain = node.firstChild(css: ".sitestr")?.stringValue ?? ""
        let age = adjacentItem.firstChild(css: ".age").flatMap(hnDate(fromAge:))
        let author = adjacentItem.firstChild(css: ".hnuser")?.stringValue

        let score: Int?
        if let scoreString = adjacentItem.firstChild(css: ".score")?.stringValue,
           let scorePrefix = scoreString.split(separator: " ").first {
            score = Int(scorePrefix)
        } else {
            score = nil
        }

        let commentCount = parseCommentCount(from: adjacentItem)
        let voteState = parseItemVoteState(itemID: id, voteNode: node, stateNode: adjacentItem)

        return ParsedHNItem(
            id: id,
            title: storyLinkNode.stringValue,
            storyLink: storyLink,
            domain: domain,
            age: age,
            author: author,
            score: score,
            commentCount: commentCount,
            voteState: voteState
        )
    }

    private static func parseCommentCount(from metadataNode: XMLElement) -> Int {
        guard let commentString = metadataNode
            .firstChild(xpath: ".//a[contains(text(), 'comment') or text()='discuss']")?
            .stringValue else {
            return 0
        }

        if commentString == "discuss" {
            return 0
        }

        let digits = commentString.prefix(while: \.isNumber)
        return digits.isEmpty ? 0 : (Int(digits) ?? 0)
    }

    private static func parseMoreLink(doc: HTMLDocument, baseURLString: String) -> String? {
        guard let moreLink = doc.css("a.morelink").first,
              let href = moreLink["href"],
              let baseURL = URL(string: baseURLString) else {
            return nil
        }

        return URL(string: href, relativeTo: baseURL)?.absoluteString
    }

    private static func resolvedStoryURL(from href: String) -> URL? {
        if href.hasPrefix("http://") || href.hasPrefix("https://") {
            return URL(string: href)
        }
        return URL(string: "https://news.ycombinator.com/\(href)")
    }

    private static func resolvedHNURL(from href: String?) -> URL? {
        guard let href else { return nil }
        return URL(string: href, relativeTo: URL(string: "https://news.ycombinator.com/"))?.absoluteURL
    }

    private static func resolvedURL(from href: String, baseURL: URL?) -> URL? {
        if href.hasPrefix("http://") || href.hasPrefix("https://") {
            return URL(string: href)
        }

        if let baseURL {
            return URL(string: href, relativeTo: baseURL)?.absoluteURL
        }

        return URL(string: href)
    }

    private static func parseItemVoteState(
        itemID: Int,
        voteNode: XMLElement,
        stateNode: XMLElement
    ) -> ParsedHNVoteState {
        let upvoteNode = voteNode.firstChild(css: "#up_\(itemID)")
        let upvoteAuth = authToken(from: upvoteNode?.attr("href"))
        let downvoteAuth = authToken(
            from: voteNode.firstChild(css: "#down_\(itemID)")?.attr("href")
        )
        let upvoteClasses = upvoteNode?.attr("class")?
            .split(separator: " ")
            .map(String.init) ?? []

        let unvoteNode = stateNode.firstChild(css: "#un_\(itemID)")
        let canResetVote = unvoteNode != nil
        var isUpvoted = false
        var isDownvoted = false
        if let unvoteNode {
            if unvoteNode.stringValue.lowercased() == "undown" {
                isDownvoted = true
            } else {
                isUpvoted = true
            }
        } else if upvoteClasses.contains("nosee") {
            isUpvoted = true
        }

        return ParsedHNVoteState(
            upvoteAuth: upvoteAuth,
            downvoteAuth: downvoteAuth,
            isUpvoted: isUpvoted,
            isDownvoted: isDownvoted,
            canResetVote: canResetVote
        )
    }

    private static func parseCommentVoteState(
        itemID: Int,
        voteNode: XMLElement,
        stateNode: XMLElement
    ) -> ParsedHNVoteState {
        let upvoteAuth = authToken(
            from: voteNode.firstChild(css: "#up_\(itemID)")?.attr("href")
        )
        let downvoteAuth = authToken(
            from: voteNode.firstChild(css: "#down_\(itemID)")?.attr("href")
        )

        let unvoteNode = stateNode.firstChild(css: "#un_\(itemID)")
        let canResetVote = unvoteNode != nil
        var isUpvoted = false
        var isDownvoted = false
        if let unvoteNode {
            if unvoteNode.stringValue.lowercased() == "undown" {
                isDownvoted = true
            } else {
                isUpvoted = true
            }
        }

        return ParsedHNVoteState(
            upvoteAuth: upvoteAuth,
            downvoteAuth: downvoteAuth,
            isUpvoted: isUpvoted,
            isDownvoted: isDownvoted,
            canResetVote: canResetVote
        )
    }

    private static func createCommentTree(nodes: NodeSet) -> [ParsedHNComment] {
        var rootComments: [ParsedHNComment] = []
        var lastCommentAtLevel: [Int: [Int]] = [:]

        for node in nodes {
            guard
                let idString = node.attr("id"),
                let id = Int(idString),
                let textNode = node.firstChild(css: ".commtext"),
                let ageNode = node.firstChild(css: ".comhead .age"),
                let age = hnDate(fromAge: ageNode)
            else {
                continue
            }

            let author = node.firstChild(css: ".comhead .hnuser")?.stringValue ?? ""
            let indentLevel = node.firstChild(css: ".ind")?["indent"].flatMap(Int.init) ?? 0
            let voteState = parseCommentVoteState(itemID: id, voteNode: node, stateNode: node)

            let comment = ParsedHNComment(
                id: id,
                author: author,
                age: age,
                indentLevel: indentLevel,
                content: parseCommentText(textNode),
                voteState: voteState
            )

            if indentLevel == 0 {
                rootComments.append(comment)
                lastCommentAtLevel[indentLevel] = [rootComments.count - 1]
                continue
            }

            guard let parentPath = lastCommentAtLevel[indentLevel - 1] else { continue }
            let insertedPath = append(comment, to: &rootComments, parentPath: parentPath)
            lastCommentAtLevel[indentLevel] = insertedPath
        }

        return rootComments
    }

    @discardableResult
    private static func append(
        _ comment: ParsedHNComment,
        to comments: inout [ParsedHNComment],
        parentPath: [Int]
    ) -> [Int] {
        let index = parentPath[0]

        if parentPath.count == 1 {
            comments[index].children.append(comment)
            return parentPath + [comments[index].children.count - 1]
        }

        let childPath = Array(parentPath.dropFirst())
        let insertedPath = append(
            comment,
            to: &comments[index].children,
            parentPath: childPath
        )
        return [index] + insertedPath
    }

    private static func authToken(from href: String?) -> String? {
        guard
            let href,
            let voteURL = URL(string: "https://news.ycombinator.com/\(href)"),
            let components = URLComponents(url: voteURL, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        return components.queryItems?.first(where: { $0.name == "auth" })?.value
    }
}
