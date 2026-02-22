import Foundation
import SkipFuse

public enum AppMode: String {
    case local = "local"
    case server = "server"
}

public class AuthService: @unchecked Sendable {
    public static let shared = AuthService()

    private let serverURLKey = "mealie_server_url"
    private let tokenKey = "mealie_access_token"
    private let userIdKey = "mealie_user_id"
    private let appModeKey = "mealie_app_mode"

    private init() {}

    // MARK: - App Mode

    public var savedAppMode: AppMode {
        get {
            let raw = UserDefaults.standard.string(forKey: appModeKey) ?? "server"
            return AppMode(rawValue: raw) ?? .server
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: appModeKey) }
    }

    public func startLocalMode() {
        savedAppMode = .local
    }

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
        if savedAppMode == .local {
            return true
        }
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
        savedAppMode = .server
        MealieAPI.shared.configure(baseURL: serverURL, token: token)
    }

    public func clearSession() {
        savedServerURL = nil
        savedToken = nil
        savedUserId = nil
        savedAppMode = .server
        MealieAPI.shared.configure(baseURL: "", token: "")
    }
}
