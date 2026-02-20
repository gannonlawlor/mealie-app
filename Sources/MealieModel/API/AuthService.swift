import Foundation
import OSLog
import SkipFuse

public class AuthService: @unchecked Sendable {
    public static let shared = AuthService()

    private let serverURLKey = "mealie_server_url"
    private let tokenKey = "mealie_access_token"
    private let userIdKey = "mealie_user_id"

    private init() {}

    // MARK: - Server URL

    public var savedServerURL: String? {
        get { UserDefaults.standard.string(forKey: serverURLKey) }
        set { UserDefaults.standard.set(newValue, forKey: serverURLKey) }
    }

    // MARK: - Token Management

    public var savedToken: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    public var savedUserId: String? {
        get { UserDefaults.standard.string(forKey: userIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: userIdKey) }
    }

    // MARK: - Session

    public func restoreSession() -> Bool {
        guard let url = savedServerURL, !url.isEmpty,
              let token = savedToken, !token.isEmpty else {
            return false
        }
        MealieAPI.shared.configure(baseURL: url, token: token)
        return true
    }

    public func saveSession(serverURL: String, token: String, userId: String) {
        savedServerURL = serverURL
        savedToken = token
        savedUserId = userId
        MealieAPI.shared.configure(baseURL: serverURL, token: token)
    }

    public func clearSession() {
        savedServerURL = nil
        savedToken = nil
        savedUserId = nil
        MealieAPI.shared.configure(baseURL: "", token: "")
    }
}
