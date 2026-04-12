import SwiftUI

struct ListingItemCellContent: View {
    var item: HNItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if !item.domain.isEmpty {
                    Text(item.domain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(item.subheading)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(String(item.commentCount))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct ListingItemCell: View {
    var item: HNItem

    var body: some View {
        NavigationLink(value: item) {
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
