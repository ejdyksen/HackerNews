//
//  ParsingTests.swift
//  HackerNewsTests
//
//  Created by E.J. Dyksen on 10/12/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import XCTest
@testable import HackerNews

class ParsingTests: XCTestCase {
    var service: HackerNewsService = HackerNewsService()
    var data: Data!

    override func setUp() {
        do {
            let testBundle = Bundle(for: type(of: self))
            let url = testBundle.url(forResource: "topstories", withExtension: "txt")!
            self.data = try Data(contentsOf: url)
            service.load()
            
        } catch {
            print(error)
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTopStories() {
        let items = service.parseTopStories(data: self.data)
        
        XCTAssert(items.count == 30)
        
        var item: Item
        
        item = items[0]
        XCTAssertEqual(item.title, "Visa, Mastercard, Stripe, and eBay exit Facebook’s Libra project")
        XCTAssertEqual(item.author!, "gkolli")
        XCTAssertEqual(item.commentCount!, 193)
        
        item = items[29]
        XCTAssertEqual(item.title, "Lion-Man")
        XCTAssertEqual(item.author!, "zeristor")
        XCTAssertEqual(item.commentCount!, 2)
        
    }

}
