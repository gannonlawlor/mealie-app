import Foundation
import SkipFuse

public enum AppMode: String {
    case local = "local"
    case server = "server"
}

public struct SavedServer: Codable, Sendable, Equatable {
    public var url: String
    public var email: String

    public init(url: String, email: String) {
        self.url = url
        self.email = email
    }
}

public class AuthService: @unchecked Sendable {
    public static let shared = AuthService()

    private let serverURLKey = "mealie_server_url"
    private let tokenKey = "mealie_access_token"
    private let userIdKey = "mealie_user_id"
    private let appModeKey = "mealie_app_mode"
    private let emailKey = "mealie_email"
    private let passwordKey = "mealie_password"
    private let savedServersKey = "mealie_saved_servers"

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

    public var savedEmail: String? {
        get { UserDefaults.standard.string(forKey: emailKey) }
        set { UserDefaults.standard.set(newValue, forKey: emailKey) }
    }

    public var savedPassword: String? {
        get { UserDefaults.standard.string(forKey: passwordKey) }
        set { UserDefaults.standard.set(newValue, forKey: passwordKey) }
    }

    // MARK: - Saved Servers

    public var savedServers: [SavedServer] {
        get {
            guard let data = UserDefaults.standard.data(forKey: savedServersKey),
                  let servers = try? JSONDecoder().decode([SavedServer].self, from: data) else {
                return []
            }
            return servers
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: savedServersKey)
            }
        }
    }

    public func addSavedServer(url: String, email: String) {
        var servers = savedServers
        servers.removeAll { $0.url == url }
        servers.insert(SavedServer(url: url, email: email), at: 0)
        if servers.count > 5 { servers = Array(servers.prefix(5)) }
        savedServers = servers
    }

    public func removeSavedServer(url: String) {
        var servers = savedServers
        servers.removeAll { $0.url == url }
        savedServers = servers
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

    public func saveSession(serverURL: String, token: String, userId: String, email: String? = nil, password: String? = nil) {
        savedServerURL = serverURL
        savedToken = token
        savedUserId = userId
        savedAppMode = .server
        if let email = email { savedEmail = email }
        if let password = password { savedPassword = password }
        if let email = email {
            addSavedServer(url: serverURL, email: email)
        }
        MealieAPI.shared.configure(baseURL: serverURL, token: token)
    }

    /// Clears auth token but preserves server URL and email for quick re-login.
    public func softClearSession() {
        savedToken = nil
        savedUserId = nil
        savedPassword = nil
        MealieAPI.shared.configure(baseURL: savedServerURL ?? "", token: "")
    }

    public func clearSession() {
        savedServerURL = nil
        savedToken = nil
        savedUserId = nil
        savedEmail = nil
        savedPassword = nil
        savedAppMode = .server
        MealieAPI.shared.configure(baseURL: "", token: "")
    }
}
