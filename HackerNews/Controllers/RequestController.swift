// Low-level HTTP transport for the app. This actor owns request retries,
// throttling, and cookie helpers, but it does not know how to parse HN pages.
import Foundation

enum RequestError: Error {
    case networkError(Error)
    case serverError(Int)
    case maxRetriesExceeded
    case invalidResponse
    case invalidURL
    case invalidBody
    case emptyResponse
}

extension RequestError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "Server is busy. Please try again later."
        case .serverError(let code):
            return "Server error (\(code)). Please try again."
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .invalidURL, .invalidResponse, .invalidBody, .emptyResponse:
            return "Unexpected response from server."
        }
    }
}

actor RequestController {
    static let shared = RequestController()

    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1"
    private let hackerNewsDomain = "news.ycombinator.com"
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0
    private let minimumRequestInterval: TimeInterval = 1.0
    private var nextRequestEarliestAt: Date = .distantPast

    private init() {}

    func request(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:],
        shouldRetry: Bool = false
    ) async throws -> Data {
        try await requestWithRetry(
            endpoint: endpoint,
            method: method,
            body: body,
            headers: headers,
            retryCount: 0,
            shouldRetry: shouldRetry
        )
    }

    func requestForm(
        endpoint: String,
        items: [URLQueryItem],
        headers: [String: String] = [:],
        shouldRetry: Bool = false
    ) async throws -> Data {
        var components = URLComponents()
        components.queryItems = items

        guard let body = components.percentEncodedQuery?.data(using: .utf8) else {
            throw RequestError.invalidBody
        }

        return try await request(
            endpoint: endpoint,
            method: "POST",
            body: body,
            headers: [
                "Content-Type": "application/x-www-form-urlencoded; charset=utf-8"
            ].merging(headers) { _, new in new },
            shouldRetry: shouldRetry
        )
    }

    func restoreUserSessionCookie(_ value: String) {
        let properties: [HTTPCookiePropertyKey: Any] = [
            .name: "user",
            .value: value,
            .domain: hackerNewsDomain,
            .path: "/",
            .secure: "TRUE"
        ]

        if let cookie = HTTPCookie(properties: properties) {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    func userSessionCookieValue() -> String? {
        HTTPCookieStorage.shared.cookies?.first(where: {
            $0.domain.contains("ycombinator.com") && $0.name == "user"
        })?.value
    }

    func clearHNSessionCookies() {
        HTTPCookieStorage.shared.cookies?
            .filter { $0.domain.contains("ycombinator.com") }
            .forEach(HTTPCookieStorage.shared.deleteCookie)
    }

    /// Reserves the next request slot, sleeping if the caller would otherwise
    /// fire within `minimumRequestInterval` of the previous reservation.
    ///
    /// Reservation advances `nextRequestEarliestAt` *before* the caller
    /// suspends on the network. Without that, two Tasks that entered the
    /// actor close together would both see the same old timestamp, both pass
    /// the guard, and issue duplicate network requests. Advancing the
    /// reservation up-front makes subsequent callers wait for the correct
    /// slot even while an earlier caller is still waiting for URLSession to
    /// resume.
    private func reserveRequestSlot() async throws {
        let now = Date()
        let earliest = max(now, nextRequestEarliestAt)
        nextRequestEarliestAt = earliest.addingTimeInterval(minimumRequestInterval)

        let waitInterval = earliest.timeIntervalSince(now)
        if waitInterval > 0 {
            try await Task.sleep(nanoseconds: UInt64(waitInterval * 1_000_000_000))
        }
    }

    private func requestWithRetry(
        endpoint: String,
        method: String,
        body: Data?,
        headers: [String: String],
        retryCount: Int,
        shouldRetry: Bool
    ) async throws -> Data {
        guard let url = URL(string: endpoint) else {
            throw RequestError.invalidURL
        }

        try await reserveRequestSlot()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RequestError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                guard !data.isEmpty else {
                    throw RequestError.emptyResponse
                }
                return data

            case 503:
                if shouldRetry && retryCount < maxRetries {
                    let delay = baseDelay * pow(2.0, Double(retryCount))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await requestWithRetry(
                        endpoint: endpoint,
                        method: method,
                        body: body,
                        headers: headers,
                        retryCount: retryCount + 1,
                        shouldRetry: shouldRetry
                    )
                } else {
                    throw shouldRetry ? RequestError.maxRetriesExceeded : RequestError.serverError(httpResponse.statusCode)
                }

            default:
                throw RequestError.serverError(httpResponse.statusCode)
            }
        } catch {
            if let requestError = error as? RequestError {
                throw requestError
            }
            throw RequestError.networkError(error)
        }
    }

}
