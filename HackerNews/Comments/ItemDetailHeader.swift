import SwiftUI

struct ItemDetailHeader: View {
    @ObservedObject var item: HNItem
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            Button { openURL(item.storyLink) } label: {
                Text(item.title)
                    .font(.title2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)

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
