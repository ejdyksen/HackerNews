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
        VStack(alignment: .leading, spacing: 10) {

            NavigationLink(destination: WebView(url: item.storyLink)) {
                Text(item.title)
                    .font(.title2)
                    .foregroundColor(.primary)
                    .padding(.top, 12)

            }

            Text(item.subheading)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            if (item.paragraphs.count > 0) {
                ForEach(item.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
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
