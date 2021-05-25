//
//  ItemCell.swift
//  HackerNews
//
//  Created by E.J. Dyksen on 5/22/21.
//

import SwiftUI

struct ListingItemCell: View {
    var item: HNItem

    var body: some View {
        NavigationLink(destination: ItemDetailContainerView(item: item)) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    + Text("  (\(item.domain))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(item.subheading)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.top, 4)

                }
                .padding(.vertical, 3)
                Spacer()
                Text(String(item.commentCount))
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                    .padding(.leading)
            }
        }
    }

}

struct ListingItemCell_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ListingItemCell(item: itemOne)
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
