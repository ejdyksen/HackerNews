import SwiftUI

struct ListingItemCellContent: View {
    var item: HNItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleWithDomain
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Text(metadata)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleWithDomain: Text {
        let title = Text(item.title)
            .font(.headline)
            .foregroundStyle(.primary)
        guard !item.domain.isEmpty else { return title }
        let domain = Text(" (\(item.domain))")
            .font(.caption)
            .foregroundStyle(.secondary)
        return Text("\(title)\(domain)")
    }

    private var metadata: String {
        var parts: [String] = []
        if let score = item.score { parts.append("\(score) pts") }
        if let author = item.author { parts.append("by \(author)") }
        parts.append(item.age)
        parts.append(" · \(item.commentCount) comments")
        return parts.joined(separator: " ")
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
