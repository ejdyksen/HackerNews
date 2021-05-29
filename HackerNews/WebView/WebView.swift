//
//  WebBrowser.swift
//  HackerNews (iOS)
//
//  Created by E.J. Dyksen on 5/27/21.
//

import SwiftUI


struct WebView: View {
    var initialUrl: URL

    @StateObject var webViewState = WebViewState()

    var body: some View {
        WebViewWraper(url: initialUrl, webViewState: webViewState)
            .navigationTitle("WebView")
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
                        actionSheet()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .bottomBar) { Spacer() }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        print("not yet implemented")
                    } label: {
                        Image(systemName: "safari")
                    }
                }

            }.accentColor(.accentColor)
    }

    func actionSheet() {
            let activityVC = UIActivityViewController(activityItems: [initialUrl], applicationActivities: nil)
            UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true, completion: nil)
        }
}

struct WebBrowser_Previews: PreviewProvider {
    static let url = URL(string: "https://www.apple.com/")!

    static var previews: some View {
        NavigationView {

            WebView(initialUrl: url)
        }
    }
}
