import SwiftUI
import WebKit

class WebViewCoordinator: NSObject {
    @ObservedObject var webViewState: WebViewState

    init(webViewState: WebViewState) {
        self.webViewState = webViewState
    }
}

extension WebViewCoordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        webViewState.loading = true
        webViewState.url = webView.url
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webViewState.loading = false
        webViewState.canGoForward = webView.canGoForward
        webViewState.canGoBack = webView.canGoBack
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webViewState.loading = false
        webViewState.canGoForward = webView.canGoForward
        webViewState.canGoBack = webView.canGoBack
        webViewState.url = webView.url
        webViewState.pageTitle = webView.title
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webViewState.loading = false
        webViewState.canGoForward = webView.canGoForward
        webViewState.canGoBack = webView.canGoBack
    }
}
