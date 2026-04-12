import SwiftUI

@MainActor final class AppState: ObservableObject {
    @Published var deepLinkItemID: Int?
}
