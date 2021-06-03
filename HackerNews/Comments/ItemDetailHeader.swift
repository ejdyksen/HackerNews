//
//  ItemDetailHeader.swift
//  HackerNews
//
//  Created by E.J. Dyksen on 6/3/21.
//

import SwiftUI


struct ItemDetailHeader: View {
    @ObservedObject var item: HNItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            NavigationLink(destination: WebView(initialUrl: item.storyLink)) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .padding(.top, 10)
            }

            Text(item.subheading)
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            if (item.paragraphs.count > 0) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(item.paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .padding(.bottom, 3)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)

                    }
                }

                Divider()
            }
        }
    }
}


struct ItemDetailHeader_Previews: PreviewProvider {
    static var previews: some View {
        ItemDetailHeader(item: HNComment.itemWithComments())
    }
}
