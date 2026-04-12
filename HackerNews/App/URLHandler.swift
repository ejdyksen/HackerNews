// Centralized URL routing for in-app links. Hacker News item URLs become app
// navigation, while external links are opened in an in-app Safari controller.
import SafariServices
import SwiftUI

public struct URLHandler: ViewModifier {
    @EnvironmentObject private var appState: AppState
    @State private var pendingURL: URL?
    @State private var pendingItemID: Int?

    public func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                if let id = Self.hnItemID(from: url) {
                    pendingItemID = id
                } else {
                    pendingURL = url
                }
                return .handled
            })
            .onChange(of: pendingItemID) { _, id in
                guard let id else { return }
                appState.deepLinkItemID = id
                pendingItemID = nil
            }
            .onChange(of: pendingURL) { _, url in
                guard let url else { return }
                presentSafari(url: url)
                pendingURL = nil
            }
    }

    private static func hnItemID(from url: URL) -> Int? {
        guard
            let host = url.host, host.contains("ycombinator.com"),
            url.path == "/item",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let id = components.queryItems?.first(where: { $0.name == "id" })?.value.flatMap(Int.init)
        else { return nil }
        return id
    }

    private func presentSafari(url: URL) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let rootVC = scene.keyWindow?.rootViewController
        else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        topVC.present(SFSafariViewController(url: url), animated: true)
    }
}

public extension View {
    func handleURLs() -> some View {
        modifier(URLHandler())
    }
}
