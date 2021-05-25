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
                VStack(alignment: .leading) {
                    Text(item.title)
                        .foregroundColor(.primary)
                        .padding(.bottom, 1)

                    Text(item.subheading)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(item.commentCount))
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                    .padding(.leading)
            }
        }
    }
}
