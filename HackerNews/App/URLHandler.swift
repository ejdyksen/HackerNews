import SafariServices
import SwiftUI

public struct URLHandler: ViewModifier {
    @State private var pendingURL: URL?

    public func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                pendingURL = url
                return .handled
            })
            .onChange(of: pendingURL) { _, url in
                guard let url else { return }
                presentSafari(url: url)
                pendingURL = nil
            }
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
