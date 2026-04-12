import Foundation
import Fuzi

enum RequestError: Error {
    case networkError(Error)
    case serverError(Int)
    case rateLimitExceeded
    case maxRetriesExceeded
    case invalidResponse
    case emptyResponse
    case htmlParseError(Error)
}

extension RequestError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .rateLimitExceeded:
            return "Loading too quickly — please wait a moment and try again."
        case .maxRetriesExceeded:
            return "Server is busy. Please try again later."
        case .serverError(let code):
            return "Server error (\(code)). Please try again."
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .htmlParseError:
            return "Couldn't read the page content. HN may have changed its layout."
        case .invalidResponse, .emptyResponse:
            return "Unexpected response from server."
        }
    }
}

actor RequestController {
    static let shared = RequestController()

    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1"
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0
    private var rateLimitQueue: [String: Date] = [:]
    private let minimumRequestInterval: TimeInterval = 1.0

    private init() {}

    func makeRequest(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        shouldRetry: Bool = false
    ) async throws -> HTMLDocument {
        return try await makeRequestWithRetry(endpoint: endpoint, method: method, body: body, retryCount: 0, shouldRetry: shouldRetry)
    }

    private func makeRequestWithRetry(
        endpoint: String,
        method: String,
        body: Data?,
        retryCount: Int,
        shouldRetry: Bool
    ) async throws -> HTMLDocument {
        // Rate limiting check
        if let lastRequestTime = rateLimitQueue[endpoint],
           Date().timeIntervalSince(lastRequestTime) < minimumRequestInterval {
            throw RequestError.rateLimitExceeded
        }

        guard let url = URL(string: endpoint) else {
            throw RequestError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RequestError.invalidResponse
            }

            // Update rate limit tracking
            rateLimitQueue[endpoint] = Date()

            switch httpResponse.statusCode {
            case 200...299:
                guard !data.isEmpty else {
                    throw RequestError.emptyResponse
                }
                do {
                    return try HTMLDocument(data: data)
                } catch {
                    throw RequestError.htmlParseError(error)
                }

            case 503:
                if shouldRetry && retryCount < maxRetries {
                    // Exponential backoff
                    let delay = baseDelay * pow(2.0, Double(retryCount))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await makeRequestWithRetry(
                        endpoint: endpoint,
                        method: method,
                        body: body,
                        retryCount: retryCount + 1,
                        shouldRetry: shouldRetry
                    )
                } else {
                    throw RequestError.serverError(httpResponse.statusCode)
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
