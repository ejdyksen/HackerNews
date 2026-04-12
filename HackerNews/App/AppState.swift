// Minimal app-wide state shared through the environment for cross-screen events
// that do not belong to a single view hierarchy, such as deep-link routing.
import SwiftUI

@MainActor final class AppState: ObservableObject {
    @Published var deepLinkItemID: Int?
}
