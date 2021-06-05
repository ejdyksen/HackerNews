//
//  Item.swift
//  HackerNews
//
//  Created by ejd on 9/27/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import Foundation
import Fuzi

class HNItem: ObservableObject, Identifiable {
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

    @Published var rootComments: [HNComment] = []
    @Published var paragraphs: [String] = []

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

    init(id: Int, title: String, storyLink: URL, domain: String, age: String, author: String, score: Int?, commentCount: Int?) {
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
            let storyLinkNode = node.firstChild(xpath: ".//a[@class='storylink']")
        else {
            return nil
        }

        // Get an item ID, which is required
        guard let idString = node.attributes["id"], let id = Int(idString) else {
            return nil
        }
        self.id = id

        // Link and title, which are required
        guard let href = storyLinkNode.attributes["href"], let storyLink = URL(string: href) else {
            return nil
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
            let scoreString = adjacentItem.firstChild(css: "#score_\(self.id)")?.stringValue,
            let scoreStringComponent = scoreString.split(separator: " ").first,
            let score = Int(scoreStringComponent) {
            self.score = score
        } else {
            self.score = nil
        }

        // Author, optional
        self.author = adjacentItem.firstChild(css: ".hnuser")?.stringValue

        // Comment count, optional
        if let commentCountString = adjacentItem.firstChild(xpath: "./td/a[last()]")?.stringValue {
            let delimiterSet = CharacterSet.whitespaces
            let commentCountComponent = commentCountString.components(separatedBy: delimiterSet)
            let firstComponent = commentCountComponent.first!
            let parseCount = Int(firstComponent)
            self.commentCount = parseCount ?? 0
        } else {
            self.commentCount = 0
        }
    }


    func loadMoreContent() {
        DispatchQueue.global(qos: .userInteractive).async {
            let url = URL(string: "https://news.ycombinator.com/item?id=\(self.id)&p=\(self.currentPage)")!
            self.currentPage = self.currentPage + 1

            let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
                do {
                    let doc = try HTMLDocument(data: data!)

                    var paragraphsToAdd = [String]()
                    let itemNode = doc.xpath("//table[@class=\"fatitem\"]//tr[4]")

                    if !itemNode.isEmpty {
                        for child in itemNode[0].childNodes(ofTypes: [.Element, .Text]) {
                            var childString = ""
                            if child.type == .Text {
                                childString = child.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            } else if child.type == .Element {
                                childString = child.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            } else {
                                assert(false, "unhandled element type")
                            }
                            if (!childString.isEmpty) {
                                paragraphsToAdd.append(childString)
                            }

                        }
                    }

                    let nodeList = doc.css("table.comment-tree tr.athing")
                    let newComments = HNComment.createCommentTree(nodes: nodeList)

                    if (doc.css(".morelink").isEmpty) {
                        self.canLoadMore = false
                    } else {
                        self.canLoadMore = true
                    }

                    DispatchQueue.main.sync {
                        self.rootComments = self.rootComments + newComments
                        self.paragraphs = paragraphsToAdd
                    }

                } catch let error {
                  print(error)
                }
            }
            dataTask.resume()
        }
    }
}
