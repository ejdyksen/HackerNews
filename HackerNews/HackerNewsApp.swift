// App entry point. This wires shared state and cache objects into the root
// SwiftUI hierarchy before handing off to the adaptive home container.
import SwiftUI

@main
struct HackerNewsApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var cache = AppCache()

    var body: some Scene {
        WindowGroup {
            AdaptiveHomeView()
                .handleURLs()
                .environmentObject(appState)
                .environmentObject(cache)
        }
    }
}
