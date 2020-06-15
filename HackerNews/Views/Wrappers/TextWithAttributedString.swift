//
//  AttributedStringWrapper.swift
//  HackerNews
//
//  Created by E.J. Dyksen on 10/13/19.
//  Copyright © 2019 ejd. All rights reserved.
//

import SwiftUI

struct TextWithAttributedString: UIViewRepresentable {
    typealias UIViewType = UILabel
    
    var attributedString: NSAttributedString

    func makeUIView(context: Context) -> UIViewType {
        let uiView = UILabel()
//        uiView.translatesAutoresizingMaskIntoConstraints = false
        
        uiView.contentMode = .scaleToFill
        uiView.numberOfLines = 0
        uiView.lineBreakMode = .byWordWrapping
//        uiView.setContentHuggingPriority(.defaultHigh, for: .vertical)
//        uiView.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        uiView.attributedText = attributedString


//        uiView.sizeToFit()
//        view.center = CGPoint.init(x: 0.0, y: 0.0)
//        uiView.autoresizingMask = [.flexibleHeight]
        return uiView
    }

    func updateUIView(_ uiView: UIViewType, context: UIViewRepresentableContext<TextWithAttributedString>) {
        uiView.attributedText = attributedString
        uiView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        uiView.setContentHuggingPriority(.defaultHigh, for: .horizontal)

    }
}
