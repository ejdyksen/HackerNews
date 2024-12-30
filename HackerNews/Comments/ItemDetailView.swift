import SwiftUI

struct ItemDetailView: View {
    @ObservedObject var item: HNItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ItemDetailHeader(item: item)
                    .padding(.horizontal)

                ForEach(item.rootComments) { rootComment in
                    CommentCell(comment: rootComment)
                }

                if item.canLoadMore {
                    HStack(alignment: .center, spacing: 10) {
                        ProgressView()
                        Text("Loading").foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .onAppear { item.loadMoreContent() }
                }
            }


        }
        .navigationTitle("\(item.commentCount) comments")
        .navigationBarTitleDisplayMode(.inline)
    }

}

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ItemDetailView(item: HNItem.itemWithComments())
            }
        }
    }
}
