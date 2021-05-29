//
//  WebViewCoordinator.swift
//  HackerNews (iOS)
//
//  Created by E.J. Dyksen on 5/27/21.
//

import Foundation
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
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webViewState.loading = false
        webViewState.canGoForward = webView.canGoForward
        webViewState.canGoBack = webView.canGoBack
    }
}
