// Minimal app-wide state shared through the environment for cross-screen events
// that do not belong to a single view hierarchy, such as deep-link routing and
// the scene-level backgrounding timestamp used for the veryStale check.
import SwiftUI

@MainActor final class AppState: ObservableObject {
    @Published var deepLinkItemID: Int?
    @Published var deepLinkUsername: String?

    var lastBackgroundedAt: Date?
}
