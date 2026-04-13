// Observable comment state. Parsed comment trees are mapped into these objects
// so views can bind to vote state without doing any HTML work.
import Foundation
import SwiftUI

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
    @Published var canResetVote: Bool = false

    var canUpvote: Bool { upvoteAuth != nil }
    var canDownvote: Bool { downvoteAuth != nil }
    var itemLink: URL { URL(string: "https://news.ycombinator.com/item?id=\(id)")! }
    var shareTitle: String { "Comment by \(author)" }

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

    static func models(from parsedComments: [ParsedHNComment]) -> [HNComment] {
        parsedComments.map(Self.model(from:))
    }

    private static func model(from parsed: ParsedHNComment) -> HNComment {
        let comment = HNComment(
            id: parsed.id,
            author: parsed.author,
            age: parsed.age,
            indentLevel: parsed.indentLevel,
            content: parsed.content
        )
        comment.setVoteAuth(
            upvoteAuth: parsed.voteState.upvoteAuth,
            downvoteAuth: parsed.voteState.downvoteAuth
        )
        comment.isUpvoted = parsed.voteState.isUpvoted
        comment.isDownvoted = parsed.voteState.isDownvoted
        comment.canResetVote = parsed.voteState.canResetVote
        comment.children = parsed.children.map(Self.model(from:))
        return comment
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
}
