import UIKit
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

class RequestController {
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

    private func showToast(message: String) {
        print("Toast: \(message)")
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }

            let toastContainer = UIView()
            toastContainer.backgroundColor = .black.withAlphaComponent(0.7)
            toastContainer.layer.cornerRadius = 10
            toastContainer.translatesAutoresizingMaskIntoConstraints = false

            let messageLabel = UILabel()
            messageLabel.text = message
            messageLabel.textColor = .white
            messageLabel.textAlignment = .center
            messageLabel.numberOfLines = 0
            messageLabel.translatesAutoresizingMaskIntoConstraints = false

            toastContainer.addSubview(messageLabel)
            window.addSubview(toastContainer)

            NSLayoutConstraint.activate([
                messageLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 16),
                messageLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -16),
                messageLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 8),
                messageLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -8),

                toastContainer.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                toastContainer.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -20)
            ])

            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
                toastContainer.alpha = 1
            }) { _ in
                UIView.animate(withDuration: 0.3, delay: 2, options: .curveEaseOut, animations: {
                    toastContainer.alpha = 0
                }) { _ in
                    toastContainer.removeFromSuperview()
                }
            }
        }
    }
}
