import Foundation
import Security

class AuthController: ObservableObject {
    @Published var isLoggedIn = false
    @Published var username: String?

    static let shared = AuthController()
    private let userSessionCookie = "user_session_cookie"

    private init() {
        loadStoredCookie()
    }

    func login(username: String, password: String) async throws -> Bool {
        let url = URL(string: "https://news.ycombinator.com/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue("https://news.ycombinator.com/", forHTTPHeaderField: "referer")

        // Include the goto parameter in the form data
        let body = "acct=\(username)&pw=\(password)"
        request.httpBody = body.data(using: .utf8)

        if let cookies = HTTPCookieStorage.shared.cookies?.filter({ $0.domain.contains("ycombinator.com") }),
           let userCookie = cookies.first(where: { $0.name == "user" }) {
            await MainActor.run {
                self.isLoggedIn = true
                self.username = username
            }
            try storeCookieValue(userCookie.value)
            return true
        }

        return false
    }

    func logout() {
        // Clear cookies from HTTPCookieStorage
        if let cookies = HTTPCookieStorage.shared.cookies {
            cookies.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        }
        deleteStoredCookie()
        isLoggedIn = false
        username = nil
    }

    private func storeCookieValue(_ value: String) throws {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userSessionCookie,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private func loadStoredCookie() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userSessionCookie,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let cookieData = result as? Data,
           let cookieValue = String(data: cookieData, encoding: .utf8) {

            let username = cookieValue.split(separator: "&").first.map(String.init) // Extract username

            let properties: [HTTPCookiePropertyKey: Any] = [
                .name: "user",
                .value: cookieValue,
                .domain: "news.ycombinator.com",
                .path: "/"
            ]

            if let cookie = HTTPCookie(properties: properties) {
                HTTPCookieStorage.shared.setCookie(cookie)
                isLoggedIn = true
                self.username = username
            }
        }
    }

    private func deleteStoredCookie() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userSessionCookie
        ]
        SecItemDelete(query as CFDictionary)
    }
}
