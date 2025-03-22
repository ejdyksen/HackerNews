import SwiftUI

public struct URLHandler: ViewModifier {
    @State private var presentedURL: URL? = nil
    @State private var showWebView = false
    
    public func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                presentedURL = url
                showWebView = true
                return .handled
            })
            .sheet(isPresented: $showWebView) {
                if let url = presentedURL {
                    NavigationView {
                        WebView(url: url)
                    }
                }
            }
    }
}

public extension View {
    func handleURLs() -> some View {
        modifier(URLHandler())
    }
}
