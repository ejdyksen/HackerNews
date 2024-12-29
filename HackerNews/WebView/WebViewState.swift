import SwiftUI

class WebViewState: ObservableObject {
    @Published var pageTitle: String?
    @Published var loading = false
    @Published var canGoBack = false
    @Published var requestGoBack = false
    @Published var canGoForward = false
    @Published var requestGoForward = false
    @Published var reload = false
    @Published var url: URL?
}
