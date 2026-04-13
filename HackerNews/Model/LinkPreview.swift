// Observable external-link preview state for story headers. This model owns one
// fetched preview image/icon and reuses it across detail views within a session.
import SwiftUI
import UIKit

enum LinkPreviewAssetKind: Equatable {
    case richImage
    case icon
}

enum LinkPreviewDisplayState {
    case idle
    case loading
    case loaded(image: UIImage, kind: LinkPreviewAssetKind)
    case unavailable
}

@MainActor final class LinkPreview: ObservableObject {
    let url: URL

    @Published private(set) var state: LinkPreviewDisplayState = .idle

    private var loadTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url
    }

    func loadInitialContent() {
        guard case .idle = state else { return }
        loadContent()
    }

    func loadContent(reload: Bool = false) {
        if reload {
            loadTask?.cancel()
            loadTask = nil
            state = .idle
        } else if loadTask != nil {
            return
        }

        state = .loading

        let targetURL = url
        loadTask = Task { [weak self] in
            guard let self else { return }

            do {
                if let result = try await LinkPreviewService.shared.fetchPreview(for: targetURL) {
                    self.state = .loaded(image: result.image, kind: result.kind)
                    debugLog("preview/\(targetURL.host ?? targetURL.absoluteString)", "loaded \(result.kind)")
                } else {
                    self.state = .unavailable
                    debugLog("preview/\(targetURL.host ?? targetURL.absoluteString)", "unavailable")
                }
            } catch is CancellationError {
                self.state = .idle
            } catch {
                self.state = .unavailable
                debugLog(
                    "preview/\(targetURL.host ?? targetURL.absoluteString)",
                    "load error: \(error.localizedDescription)"
                )
            }

            self.loadTask = nil
        }
    }
}
