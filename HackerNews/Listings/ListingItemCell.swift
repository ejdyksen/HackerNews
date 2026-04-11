import SwiftUI

struct ListingItemCellContent: View {
    var item: HNItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(item.title)\(Text(item.domainString).font(.caption).foregroundColor(.secondary).baselineOffset(1))")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(item.subheading)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 4)

            }.padding(.vertical, 4)

            Spacer()

            Text(String(item.commentCount))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading)
        }
    }
}

struct ListingItemCell: View {
    var item: HNItem

    var body: some View {
        NavigationLink(destination: ItemDetailView(item: item)) {
            ListingItemCellContent(item: item)
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
