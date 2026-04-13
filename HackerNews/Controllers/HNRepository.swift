// Hacker News-specific data access. This actor knows which pages to fetch and
// which parser entry point to call, but leaves HTTP mechanics to RequestController.
import Foundation

enum HNVoteAction: String {
    case up
    case down
    case un
}

actor HNRepository {
    static let shared = HNRepository()

    func fetchListingPage(
        destination: HNListingDestination,
        nextPageURL: String?
    ) async throws -> ParsedHNListingPage {
        let endpoint = nextPageURL ?? destination.endpointURLString
        let data = try await RequestController.shared.request(
            endpoint: endpoint,
            shouldRetry: true
        )
        return try HNHTMLParser.parseListingPage(data: data, baseURLString: endpoint)
    }

    func fetchItemPage(itemID: Int, page: Int) async throws -> ParsedHNItemPage {
        let endpoint = "https://news.ycombinator.com/item?id=\(itemID)&p=\(page)"
        let data = try await RequestController.shared.request(
            endpoint: endpoint,
            shouldRetry: true
        )
        return try HNHTMLParser.parseItemPage(data: data)
    }

    func fetchUserPage(username: String) async throws -> ParsedHNUserPage {
        var components = URLComponents(string: "https://news.ycombinator.com/user")
        components?.queryItems = [URLQueryItem(name: "id", value: username)]
        guard let endpoint = components?.url?.absoluteString else {
            throw RequestError.invalidURL
        }

        let data = try await RequestController.shared.request(
            endpoint: endpoint,
            shouldRetry: true
        )
        return try HNHTMLParser.parseUserPage(data: data)
    }

    func submitVote(itemID: Int, action: HNVoteAction, auth: String) async throws {
        let endpoint = "https://news.ycombinator.com/vote?id=\(itemID)&how=\(action.rawValue)&auth=\(auth)&goto=item%3Fid%3D\(itemID)&js=t"
        _ = try await RequestController.shared.request(endpoint: endpoint)
    }
}
