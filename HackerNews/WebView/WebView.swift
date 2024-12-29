import SwiftUI

struct WebView: View {
    var url: URL

    @StateObject var webViewState = WebViewState()

    @State private var isSharePresented: Bool = false

    @Environment(\.openURL) var openURL

    var body: some View {
        WebViewWraper(url: url, webViewState: webViewState)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {Text("")}
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        if (self.webViewState.canGoBack) {
                            self.webViewState.requestGoBack.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.backward")
                    }.disabled(!self.webViewState.canGoBack)
                }
                ToolbarItem(placement: .bottomBar) { Spacer() }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        if (self.webViewState.canGoForward) {
                            self.webViewState.requestGoForward.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.forward")
                    }.disabled(!self.webViewState.canGoForward)

                }
                ToolbarItem(placement: .bottomBar) { Spacer() }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        self.isSharePresented = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .sheet(isPresented: $isSharePresented, onDismiss: {
                        print("Dismiss")
                    }, content: {
                        ActivityView(activityItems: [URL(string: "https://www.apple.com")!])
                    })

                }
                ToolbarItem(placement: .bottomBar) { Spacer() }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        if (webViewState.url != nil) {
                            openURL(webViewState.url!)
                        }
                    } label: {
                        Image(systemName: "safari")
                    }.disabled(self.webViewState.url == nil)
                }

            }.accentColor(.accentColor)
    }
}

struct WebBrowser_Previews: PreviewProvider {
    static let url = URL(string: "https://www.apple.com/")!

    static var previews: some View {
        NavigationView {
            WebView(url: url)
        }
    }
}
