// App entry point. Wires shared state and cache objects into the root SwiftUI
// hierarchy and watches scenePhase so that a sufficiently long backgrounding
// marks every cached listing as needing a fresh reload on next appearance.
import SwiftUI

@main
struct HackerNewsApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var cache = AppCache()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AdaptiveHomeView()
                .handleURLs()
                .environmentObject(appState)
                .environmentObject(cache)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                appState.lastBackgroundedAt = .now
            } else if scenePhase == .active {
                if let bg = appState.lastBackgroundedAt,
                   Date.now.timeIntervalSince(bg) > Freshness.veryStaleThreshold {
                    cache.markListingsForFreshLoad()
                }
                appState.lastBackgroundedAt = nil
            }
        }
    }
}
