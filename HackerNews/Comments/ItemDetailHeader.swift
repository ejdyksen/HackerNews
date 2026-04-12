import SwiftUI

struct ItemDetailHeader: View {
    @ObservedObject var item: HNItem
    @Environment(\.openURL) private var openURL

    private var isSelfLink: Bool {
        item.storyLink.absoluteString == item.itemLink.absoluteString
    }

    private var titleWithDomain: Text {
        let title = Text(item.title)
            .font(.title2)
            .foregroundStyle(.primary)
        guard !item.domain.isEmpty else { return title }
        let domain = Text("(\(item.domain))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        return Text("\(title) \(domain)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            if isSelfLink {
                titleWithDomain
                    .multilineTextAlignment(.leading)
            } else {
                Button { openURL(item.storyLink) } label: {
                    titleWithDomain
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }

            Text(item.subheading)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            if let body = item.body {
                Text(body)

                Divider()
            }
        }
    }
}

struct ItemDetailHeader_Previews: PreviewProvider {
    static var previews: some View {
        ItemDetailHeader(item: HNItem.itemWithComments())
    }
}
