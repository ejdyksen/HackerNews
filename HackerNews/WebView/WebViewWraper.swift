import SwiftUI
import WebKit

struct WebViewWraper : UIViewRepresentable {
    let url: URL

    @ObservedObject var webViewState: WebViewState

    func makeUIView(context: Context) -> WKWebView  {
        let webview = WKWebView()

        let request = URLRequest(url: self.url, cachePolicy: .returnCacheDataElseLoad)
        webview.allowsBackForwardNavigationGestures = true
        webview.navigationDelegate = context.coordinator
        webview.load(request)

        return webview
    }

    func updateUIView(_ webView: WKWebView, context: UIViewRepresentableContext<WebViewWraper>) {
        if webView.canGoBack, webViewState.requestGoBack {
            webView.goBack()
            webViewState.requestGoBack = false
        } else if webView.canGoForward, webViewState.requestGoForward {
            webView.goForward()
            webViewState.requestGoForward = false
        } else if webViewState.reload {
            webView.reload()
            webViewState.reload = false
        }
    }

    func makeCoordinator() -> WebViewCoordinator {
        return WebViewCoordinator(webViewState: webViewState)
    }

}
