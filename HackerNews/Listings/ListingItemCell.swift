import SwiftUI

struct ListingItemCell: View {
    var item: HNItem

    var body: some View {
        NavigationLink(destination: ItemDetailView(item: item)) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    + Text(item.domainString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .baselineOffset(1)

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
