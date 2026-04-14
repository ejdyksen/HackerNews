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
    /// Base URL used to resolve relative links inside HN-authored rich text
    /// (comment bodies, self-post bodies, user about fields). HN markup emits
    /// hrefs like `item?id=123` and `user?id=pg` without a host, so these must
    /// be resolved against the site root before they become routable URLs.
    static let hnBaseURL = URL(string: "https://news.ycombinator.com/")!

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
        try PerfLog.measure(PerfLog.parser, "parseItemPage") {
            let doc = try PerfLog.measure(PerfLog.parser, "htmlParse") {
                try document(from: data)
            }

            let metadata = PerfLog.measure(PerfLog.parser, "itemMetadata") {
                doc.css("table.fatitem tr.athing").first.flatMap(parseItem)
            }
            let body = PerfLog.measure(PerfLog.parser, "itemBody") {
                doc.css("table.fatitem .commtext").first
                    .map { parseCommentText($0) }
                    .flatMap { $0.characters.isEmpty ? nil : $0 }
            }
            let rootComments = PerfLog.measure(PerfLog.parser, "commentTree") {
                createCommentTree(nodes: doc.css("table.comment-tree tr.athing"))
            }
            let hasMoreContent = !doc.css(".morelink").isEmpty

            return ParsedHNItemPage(
                metadata: metadata,
                body: body,
                rootComments: rootComments,
                hasMoreContent: hasMoreContent
            )
        }
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
            .map { parseRichText($0, baseURL: hnBaseURL) }
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

    static func parseCommentText(
        _ node: XMLElement,
        italicFont: UIFont? = nil,
        monoFont: UIFont? = nil
    ) -> AttributedString {
        parseRichText(node, baseURL: hnBaseURL, italicFont: italicFont, monoFont: monoFont)
    }

    static func parseRichText(
        _ node: XMLElement,
        baseURL: URL? = nil,
        italicFont: UIFont? = nil,
        monoFont: UIFont? = nil
    ) -> AttributedString {
        // Resolve fonts once. Recursive calls pass the resolved values down so
        // bodyItalicFont / bodyMonospacedFont (which call into UIKit) are never
        // hit per-element on the hot comment path.
        let italic = italicFont ?? bodyItalicFont
        let mono = monoFont ?? bodyMonospacedFont

        var result = AttributedString()
        var previousRenderedBlock: RenderedBlock? = nil

        for child in node.childNodes(ofTypes: [.Element, .Text]) {
            if child.type == .Text {
                let text = normalizedInlineText(from: child.stringValue)
                guard !text.isEmpty else { continue }
                if previousRenderedBlock == .pre && !result.characters.isEmpty {
                    result += AttributedString("\n\n")
                }
                result += AttributedString(text)
                previousRenderedBlock = nil
                continue
            }

            guard let element = child as? XMLElement else { continue }

            switch element.tag {
            case "p":
                let paragraph = parseRichText(element, baseURL: baseURL, italicFont: italic, monoFont: mono)
                guard !paragraph.characters.isEmpty else { continue }
                if !result.characters.isEmpty {
                    result += AttributedString("\n\n")
                }
                result += paragraph
                previousRenderedBlock = .paragraph
            case "i":
                var italicRun = parseRichText(element, baseURL: baseURL, italicFont: italic, monoFont: mono)
                italicRun.font = italic
                result += italicRun
                previousRenderedBlock = nil
            case "pre":
                if !result.characters.isEmpty {
                    result += AttributedString("\n\n")
                }
                let preformattedText = trimmedPreformattedText(from: element.stringValue)
                guard !preformattedText.isEmpty else { continue }
                var code = AttributedString(preformattedText)
                code.font = mono
                result += code
                previousRenderedBlock = .pre
            case "code":
                var code = AttributedString(element.stringValue)
                code.font = mono
                result += code
                previousRenderedBlock = nil
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
                previousRenderedBlock = nil
            default:
                result += parseRichText(element, baseURL: baseURL, italicFont: italic, monoFont: mono)
                previousRenderedBlock = nil
            }
        }

        return result
    }

    /// Single-pass whitespace collapse. No regex, no NSString round-trip, no
    /// throwaway trim-allocation early-out. Matches the previous semantics:
    /// any run of Unicode whitespace becomes a single space; leading/trailing
    /// whitespace is preserved (the original regex also preserved it — the
    /// trim was only used as an emptiness check).
    private static func normalizedInlineText(from text: String) -> String {
        var out = String()
        out.reserveCapacity(text.utf8.count)
        var pendingSpace = false
        var sawNonWhitespace = false
        var leadingWhitespace = false

        for scalar in text.unicodeScalars {
            if scalar.properties.isWhitespace {
                if sawNonWhitespace {
                    pendingSpace = true
                } else {
                    leadingWhitespace = true
                }
            } else {
                if leadingWhitespace {
                    out.unicodeScalars.append(" ")
                    leadingWhitespace = false
                }
                if pendingSpace {
                    out.unicodeScalars.append(" ")
                    pendingSpace = false
                }
                out.unicodeScalars.append(scalar)
                sawNonWhitespace = true
            }
        }

        if !sawNonWhitespace { return "" }
        if pendingSpace { out.unicodeScalars.append(" ") }
        return out
    }

    private static func trimmedPreformattedText(from text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
    }

    /// HN's `.age` span carries a `title` attribute in the form
    /// "2026-04-12T18:30:29 1776018629" — local ISO time plus a Unix timestamp.
    /// We parse the Unix timestamp since it's timezone-unambiguous.
    private static func hnDate(fromAge element: XMLElement) -> Date? {
        guard let title = element["title"] else { return nil }
        let parts = title.split(separator: " ")
        guard parts.count >= 2, let unix = TimeInterval(parts[1]) else { return nil }
        return Date(timeIntervalSince1970: unix)
    }

    private static var bodyTextSize: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).pointSize
    }

    private static var bodyItalicFont: UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withSymbolicTraits(.traitItalic)
        return UIFont(descriptor: descriptor ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body),
                      size: bodyTextSize)
    }

    private static var bodyMonospacedFont: UIFont {
        .monospacedSystemFont(ofSize: bodyTextSize - 3, weight: .regular)
    }

    private enum RenderedBlock {
        case paragraph
        case pre
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

    private static func createCommentTree(nodes: NodeSet) -> [ParsedHNComment] {
        // Hoist UIFont lookups out of the per-row hot path so the recursive
        // rich-text builder doesn't hit UIKit on every <i>, <pre>, or <code>.
        let italicFont = bodyItalicFont
        let monoFont = bodyMonospacedFont

        var rootComments: [ParsedHNComment] = []
        var lastCommentAtLevel: [Int: [Int]] = [:]
        var commentCount = 0

        for node in nodes {
            commentCount += 1
            guard let comment = parseCommentRow(
                node,
                italicFont: italicFont,
                monoFont: monoFont
            ) else {
                continue
            }

            if comment.indentLevel == 0 {
                rootComments.append(comment)
                lastCommentAtLevel[comment.indentLevel] = [rootComments.count - 1]
                continue
            }

            guard let parentPath = lastCommentAtLevel[comment.indentLevel - 1] else {
                debugLog(
                    "parser/comments",
                    "dropping comment \(comment.id): missing parent path for indent \(comment.indentLevel)"
                )
                continue
            }
            let insertedPath = append(comment, to: &rootComments, parentPath: parentPath)
            lastCommentAtLevel[comment.indentLevel] = insertedPath
        }

        PerfLog.logger.info("commentTree count=\(commentCount, privacy: .public)")
        return rootComments
    }

    // Walks a comment <tr> using direct child accessors instead of CSS selectors.
    // HN's row markup is fixed:
    //   tr.athing#ID > td > table > tr > [td.ind, td.votelinks, td.default]
    //   td.default holds an unclassed div containing span.comhead, plus
    //   div.comment > div.commtext for the body.
    // Every CSS query on the parser's hot path becomes a linked-list walk over
    // libxml2 child nodes. If HN ever changes the markup the structural-miss
    // debugLog below makes the failure loud.
    private static func parseCommentRow(
        _ row: XMLElement,
        italicFont: UIFont,
        monoFont: UIFont
    ) -> ParsedHNComment? {
        guard let idString = row.attr("id"), let id = Int(idString) else {
            return nil
        }

        guard
            let outerTd = row.firstChild(staticTag: "td"),
            let innerTable = outerTd.firstChild(staticTag: "table"),
            let innerTR = innerTable.firstChild(staticTag: "tr")
        else {
            debugLog("parser/comments", "structural miss (no inner tr) for id=\(id)")
            return nil
        }

        var indentLevel = 0
        var upvoteAuth: String? = nil
        var downvoteAuth: String? = nil
        var canResetVote = false
        var isUpvoted = false
        var isDownvoted = false
        var author = ""
        var ageDate: Date? = nil
        var commTextNode: XMLElement? = nil

        for cell in innerTR.children(staticTag: "td") {
            switch cell.attr("class") {
            case "ind":
                if let s = cell.attr("indent"), let n = Int(s) {
                    indentLevel = n
                }
            case "votelinks":
                if let center = cell.firstChild(staticTag: "center") {
                    for a in center.children(staticTag: "a") {
                        let aid = a.attr("id") ?? ""
                        if aid.hasPrefix("up_") {
                            upvoteAuth = authToken(from: a.attr("href"))
                        } else if aid.hasPrefix("down_") {
                            downvoteAuth = authToken(from: a.attr("href"))
                        }
                    }
                }
            case "default":
                for div in cell.children(staticTag: "div") {
                    if div.attr("class") == "comment" {
                        commTextNode = div.children(staticTag: "div").first { d in
                            (d.attr("class") ?? "").hasPrefix("commtext")
                        }
                        continue
                    }
                    // The comhead-containing div has no class.
                    guard let comhead = div.children(staticTag: "span").first(where: {
                        $0.attr("class") == "comhead"
                    }) else { continue }

                    for child in comhead.children {
                        switch child.tag {
                        case "a":
                            let cls = child.attr("class") ?? ""
                            let cid = child.attr("id") ?? ""
                            if cls == "hnuser" {
                                author = child.stringValue
                            } else if cid.hasPrefix("un_") {
                                canResetVote = true
                                if child.stringValue.lowercased() == "undown" {
                                    isDownvoted = true
                                } else {
                                    isUpvoted = true
                                }
                            }
                        case "span":
                            if child.attr("class") == "age" {
                                ageDate = hnDate(fromAge: child)
                            }
                        default:
                            break
                        }
                    }
                }
            default:
                break
            }
        }

        guard let age = ageDate, let textNode = commTextNode else {
            debugLog("parser/comments", "structural miss (no age/commtext) for id=\(id)")
            return nil
        }

        return ParsedHNComment(
            id: id,
            author: author,
            age: age,
            indentLevel: indentLevel,
            content: parseCommentText(textNode, italicFont: italicFont, monoFont: monoFont),
            voteState: ParsedHNVoteState(
                upvoteAuth: upvoteAuth,
                downvoteAuth: downvoteAuth,
                isUpvoted: isUpvoted,
                isDownvoted: isDownvoted,
                canResetVote: canResetVote
            )
        )
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
