// Authentication state for the HN web session. This object logs in through the
// real Hacker News form flow and persists the resulting session cookie.
import Foundation
import Security

@MainActor final class AuthController: ObservableObject {
    @Published var isLoggedIn = false
    @Published var username: String?

    static let shared = AuthController()

    private let keychainService = "com.ejd.HackerNews.auth"
    private let cookieAccount = "user_session_cookie"
    private let usernameAccount = "user_session_username"

    private init() {
        Task {
            await restoreStoredSession()
        }
    }

    func login(username: String, password: String) async throws -> Bool {
        _ = try await RequestController.shared.requestForm(
            endpoint: "https://news.ycombinator.com/login",
            items: [
                URLQueryItem(name: "goto", value: "news"),
                URLQueryItem(name: "acct", value: username),
                URLQueryItem(name: "pw", value: password)
            ],
            headers: [
                "Origin": "https://news.ycombinator.com",
                "Referer": "https://news.ycombinator.com/"
            ],
            shouldRetry: true
        )

        guard let cookieValue = await RequestController.shared.userSessionCookieValue() else {
            await RequestController.shared.clearHNSessionCookies()
            return false
        }

        try storeString(cookieValue, account: cookieAccount)
        try storeString(username, account: usernameAccount)

        isLoggedIn = true
        self.username = username
        return true
    }

    func logout() async {
        await RequestController.shared.clearHNSessionCookies()
        deleteStoredValue(account: cookieAccount)
        deleteStoredValue(account: usernameAccount)
        isLoggedIn = false
        username = nil
    }

    private func restoreStoredSession() async {
        guard let cookieValue = loadString(account: cookieAccount) else { return }

        await RequestController.shared.restoreUserSessionCookie(cookieValue)
        isLoggedIn = true
        username = loadString(account: usernameAccount)
    }

    private func storeString(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private func loadString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func deleteStoredValue(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
