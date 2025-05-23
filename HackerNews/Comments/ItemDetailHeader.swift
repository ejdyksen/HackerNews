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
                    .multilineTextAlignment(.leading) // TODO: doesn't seem like I should need this.
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
        ItemDetailHeader(item: HNItem.itemWithComments())
    }
}
