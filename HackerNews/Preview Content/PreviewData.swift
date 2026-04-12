// Static preview fixtures used by SwiftUI previews so view work does not depend
// on live network requests or real Hacker News sessions.
import Foundation
import Fuzi

var itemOne = HNItem(id: 123,
                   title: "This is a story with a particularly long title that I built in one day",
                   storyLink: URL(string: "https://www.example.com")!,
                   domain: "example.com",
                   age: Date().addingTimeInterval(-2 * 60 * 60),
                   author: "ejdyksen",
                   score: 123,
                   commentCount: 123)

// Helper function to create AttributedString from HTML content
private func createCommentContent(_ html: String) -> AttributedString {
    let doc = try! HTMLDocument(string: html)
    return HNHTMLParser.parseCommentText(doc.body!)
}

// Sample comment with various HN formatting features
let comment1 = HNComment(
    id: 1,
    author: "dang",
    age: Date().addingTimeInterval(-60 * 60),
    indentLevel: 0,
    content: createCommentContent("""
        This is a thoughtful comment about programming languages and their trade-offs.

        I think there are a few key points to consider:

        1. *Performance* is critical for certain applications
        2. Developer productivity often depends on good tooling
        3. Here's an example in Python:
        <pre>
        def hello():
            print("Hello HN!")
            return True
        </pre>

        You might want to check out <a href="https://news.ycombinator.com/item?id=123456">this previous discussion</a> where we talked about similar topics.
        """)
)

// Sample reply with different formatting
var comment2 = HNComment(
    id: 2,
    author: "tptacek",
    age: Date().addingTimeInterval(-45 * 60),
    indentLevel: 1,
    content: createCommentContent("""
        *Interesting analysis!* I particularly agree with your point about tooling.

        However, I think we should also consider the ecosystem and community support. For example, <a href="https://news.ycombinator.com/item?id=987654">this article</a> shows how community-driven development can lead to better outcomes.

        Here's a counter-example in Rust:
        <pre>
        fn main() {
            println!("Different perspective!");
        }
        </pre>
        """)
)

// A deeper nested reply
let comment3 = HNComment(
    id: 3,
    author: "patio11",
    age: Date().addingTimeInterval(-30 * 60),
    indentLevel: 2,
    content: createCommentContent("""
        Speaking from experience building large-scale systems, I've found that *both* approaches have merit.

        The key is understanding your specific constraints and requirements. Sometimes the "obvious" choice isn't actually optimal for your use case.
        """)
)

// Create comment thread

extension HNItem {
    static func itemWithComments() -> HNItem {
        comment2.children = [comment3]
        comment1.children = [comment2]

        let item = itemOne
        item.rootComments = [comment1]
        return item
    }
}
