//
//  Comment.swift
//  HackerNews
//
//  Created by ejd on 9/30/19.
//  Copyright 2019 ejd. All rights reserved.
//

import Foundation
import Fuzi
import SwiftUI
import Combine

@MainActor class HNComment: Identifiable, ObservableObject {
    let id: Int
    let author: String
    let age: Date
    let indentLevel: Int
    let content: AttributedString
    var children: [HNComment] = []
    private var upvoteAuth: String?
    private var downvoteAuth: String?
    @Published var isUpvoted: Bool = false
    @Published var isDownvoted: Bool = false

    var canUpvote: Bool { upvoteAuth != nil }
    var canDownvote: Bool { downvoteAuth != nil }

    nonisolated init(id: Int, author: String, age: Date, indentLevel: Int, content: AttributedString) {
        self.id = id
        self.author = author
        self.age = age
        self.indentLevel = indentLevel
        self.content = content
    }
    
    func setVoteAuth(upvoteAuth: String?, downvoteAuth: String?) {
        self.upvoteAuth = upvoteAuth
        self.downvoteAuth = downvoteAuth
    }

    nonisolated static func parseText(_ node: XMLElement) -> AttributedString {
        var result = AttributedString()

        // Handle text nodes and elements
        for child in node.childNodes(ofTypes: [.Element, .Text]) {
            if child.type == .Text {
                result += AttributedString(child.stringValue)
            } else if let element = child as? XMLElement {
                switch element.tag {
                case "p":
                    if result.characters.count > 0 {
                        result += AttributedString("\n\n")
                    }
                    result += parseText(element)
                case "i":
                    var italic = parseText(element)
                    italic.font = .italicSystemFont(ofSize: UIFont.systemFontSize)
                    result += italic
                case "pre", "code":
                    if result.characters.count > 0 {
                        result += AttributedString("\n\n")
                    }
                    var code = AttributedString(element.stringValue)
                    code.font = .monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)
                    result += code
                case "a":
                    let href = element.attr("href") ?? ""
                    var displayUrl = href
                    if displayUrl.count > 50 {
                        displayUrl = String(displayUrl.prefix(47)) + "..."
                    }
                    var link = AttributedString(displayUrl)
                    if let url = URL(string: href) {
                        link.link = url
                    }
                    link.foregroundColor = .blue
                    result += link
                default:
                    result += parseText(element)
                }
            }
        }

        return result
    }

    @MainActor static func createCommentTree(nodes: NodeSet) -> [HNComment] {
        var rootComments: [HNComment] = []
        var lastCommentAtLevel = [Int: HNComment]()

        for node in nodes {
            guard let idString = node.attr("id"), let id = Int(idString) else { continue }
            guard let textNode = node.firstChild(css: ".commtext") else {
                continue
            }

            // Parse the content into AttributedString
            let content = parseText(textNode)

            // Get other comment metadata
            let author = node.firstChild(css: ".comhead .hnuser")?.stringValue ?? ""
            guard let ageNode = node.firstChild(css: ".comhead .age"),
                  let age = hnDate(fromAge: ageNode) else {
                continue
            }
            let indentLevel = node.firstChild(css: ".ind")?["indent"].flatMap(Int.init) ?? 0
            
            // Extract auth tokens from upvote/downvote links if they exist
            var upvoteAuth: String? = nil
            var downvoteAuth: String? = nil
            
            if let upvoteLink = node.firstChild(css: "#up_\(id)")?.attr("href"),
               let upvoteUrl = URL(string: "https://news.ycombinator.com/\(upvoteLink)"),
               let components = URLComponents(url: upvoteUrl, resolvingAgainstBaseURL: false),
               let auth = components.queryItems?.first(where: { $0.name == "auth" })?.value {
                upvoteAuth = auth
            }
            
            if let downvoteLink = node.firstChild(css: "#down_\(id)")?.attr("href"),
               let downvoteUrl = URL(string: "https://news.ycombinator.com/\(downvoteLink)"),
               let components = URLComponents(url: downvoteUrl, resolvingAgainstBaseURL: false),
               let auth = components.queryItems?.first(where: { $0.name == "auth" })?.value {
                downvoteAuth = auth
            }

            let comment = HNComment(id: id, author: author, age: age, indentLevel: indentLevel, content: content)
            comment.setVoteAuth(upvoteAuth: upvoteAuth, downvoteAuth: downvoteAuth)

            if indentLevel == 0 {
                rootComments.append(comment)
            } else if let parent = lastCommentAtLevel[indentLevel - 1] {
                parent.children.append(comment)
            }

            lastCommentAtLevel[indentLevel] = comment
        }

        return rootComments
    }

    // Add upvoting functionality
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
        // Use the appropriate auth token based on current vote state
        guard let auth = isUpvoted ? upvoteAuth : downvoteAuth else { return }
        
        let voteEndpoint = "https://news.ycombinator.com/vote?id=\(id)&how=un&auth=\(auth)&goto=item%3Fid%3D\(id)&js=t"
        _ = try await RequestController.shared.makeRequest(endpoint: voteEndpoint)
        isUpvoted = false
        isDownvoted = false
    }
}
