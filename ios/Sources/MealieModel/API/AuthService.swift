import Foundation

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

    /// Session state lives in the App Group container so the Share Extension
    /// can import a shared link itself instead of only queueing it. Falls back
    /// to standard defaults if the entitlement is missing.
    let store: UserDefaults

    private init() {
        store = SharedAppGroup.defaults ?? .standard
        migrateFromStandardDefaults()
    }

    /// Copies a pre-App-Group session into the group container so updating the
    /// app does not log anyone out. Idempotent: it only fills keys the group
    /// container is missing, and clears each one from standard defaults after,
    /// so later launches find nothing left to move.
    private func migrateFromStandardDefaults() {
        guard store != UserDefaults.standard else { return }
        let standard = UserDefaults.standard
        for key in [serverURLKey, tokenKey, userIdKey, appModeKey, emailKey, passwordKey] {
            guard let value = standard.string(forKey: key) else { continue }
            if store.string(forKey: key) == nil {
                store.set(value, forKey: key)
            }
            standard.removeObject(forKey: key)
        }
        if let servers = standard.data(forKey: savedServersKey) {
            if store.data(forKey: savedServersKey) == nil {
                store.set(servers, forKey: savedServersKey)
            }
            standard.removeObject(forKey: savedServersKey)
        }
    }

    // MARK: - App Mode

    public var savedAppMode: AppMode {
        get {
            let raw = store.string(forKey: appModeKey) ?? "server"
            return AppMode(rawValue: raw) ?? .server
        }
        set { store.set(newValue.rawValue, forKey: appModeKey) }
    }

    public func startLocalMode() {
        savedAppMode = .local
    }

    // MARK: - Server URL

    public var savedServerURL: String? {
        get { store.string(forKey: serverURLKey) }
        set { store.set(newValue, forKey: serverURLKey) }
    }

    // MARK: - Token Management

    public var savedToken: String? {
        get { store.string(forKey: tokenKey) }
        set { store.set(newValue, forKey: tokenKey) }
    }

    public var savedUserId: String? {
        get { store.string(forKey: userIdKey) }
        set { store.set(newValue, forKey: userIdKey) }
    }

    public var savedEmail: String? {
        get { store.string(forKey: emailKey) }
        set { store.set(newValue, forKey: emailKey) }
    }

    public var savedPassword: String? {
        get { store.string(forKey: passwordKey) }
        set { store.set(newValue, forKey: passwordKey) }
    }

    // MARK: - Saved Servers

    public var savedServers: [SavedServer] {
        get {
            guard let data = store.data(forKey: savedServersKey),
                  let servers = try? JSONDecoder().decode([SavedServer].self, from: data) else {
                return []
            }
            return servers
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                store.set(data, forKey: savedServersKey)
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
