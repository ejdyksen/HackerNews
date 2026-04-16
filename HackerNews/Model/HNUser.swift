// Observable user profile state. This model owns one Hacker News user page and
// its in-flight loading state after parsed data has been fetched elsewhere.
import Foundation
import SwiftUI

struct HNUserRoute: Hashable {
    let username: String
}

@MainActor final class HNUser: ObservableObject {
    let username: String

    @Published var displayName: String
    @Published var createdText: String?
    @Published var karma: Int?
    @Published var about: AttributedString?
    @Published var submissionsURL: URL?
    @Published var commentsURL: URL?
    @Published var favoritesURL: URL?
    @Published var isLoading = false
    @Published var loadError: String?
    @Published private(set) var lastUpdated: Date?

    private var loadTask: Task<Void, Never>?
    private var activeLoadID: UUID?

    init(username: String) {
        self.username = username
        self.displayName = username
    }

    func loadInitialContent() {
        if createdText == nil, karma == nil, about == nil, !isLoading {
            loadContent()
        }
    }

    func loadContent(reload: Bool = false) async {
        await startLoad(reload: reload).value
    }

    func loadContent(reload: Bool = false) {
        _ = startLoad(reload: reload)
    }

    @discardableResult
    private func startLoad(reload: Bool) -> Task<Void, Never> {
        if reload {
            loadTask?.cancel()
            loadTask = nil
        } else if let loadTask {
            return loadTask
        }

        isLoading = true
        loadError = nil

        let loadID = UUID()
        activeLoadID = loadID

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let page = try await HNRepository.shared.fetchUserPage(username: self.username)
                self.finishLoad(loadID: loadID, result: .success(page))
            } catch is CancellationError {
                self.finishCancellation(loadID: loadID)
            } catch {
                self.finishLoad(loadID: loadID, result: .failure(error))
            }
        }

        loadTask = task
        return task
    }

    private func finishLoad(loadID: UUID, result: Result<ParsedHNUserPage, Error>) {
        guard activeLoadID == loadID else { return }

        defer {
            loadTask = nil
            isLoading = false
        }

        switch result {
        case .success(let page):
            displayName = page.username
            createdText = page.createdText
            karma = page.karma
            about = page.about
            submissionsURL = page.submissionsURL
            commentsURL = page.commentsURL
            favoritesURL = page.favoritesURL
            loadError = nil
            lastUpdated = .now
            debugLog("user/\(username)", "loaded profile")

        case .failure(let error):
            loadError = error.localizedDescription
            debugLog("user/\(username)", "load error: \(error.localizedDescription)")
        }
    }

    private func finishCancellation(loadID: UUID) {
        guard activeLoadID == loadID else { return }
        loadTask = nil
        isLoading = false
    }
}
