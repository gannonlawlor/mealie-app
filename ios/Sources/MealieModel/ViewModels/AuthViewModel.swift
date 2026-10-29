import Foundation
import Observation

private let logger = Log(category: "Auth")

@MainActor @Observable public class AuthViewModel {
    public var serverURL: String = ""
    public var email: String = ""
    public var password: String = ""
    public var isLoading: Bool = false
    public var errorMessage: String = ""
    public var isAuthenticated: Bool = false
    public var isServerConnected: Bool = false
    public var currentUser: User? = nil
    public var serverInfo: AppInfo? = nil
    public var showServerSetup: Bool = true

    public var savedServers: [SavedServer] = []

    public var isLocalMode: Bool {
        AuthService.shared.savedAppMode == .local
    }

    public init() {
        savedServers = AuthService.shared.savedServers
        if AuthService.shared.savedAppMode == .local {
            isAuthenticated = true
            showServerSetup = false
        } else if AuthService.shared.restoreSession() {
            isAuthenticated = true
            isServerConnected = true
            showServerSetup = false
            serverURL = AuthService.shared.savedServerURL ?? ""
        }
    }

    public func enterLocalMode() {
        AuthService.shared.startLocalMode()
        isAuthenticated = true
        showServerSetup = false
    }

    public func validateServer() async {
        isLoading = true
        errorMessage = ""

        let url = Self.normalizeServerURL(serverURL)

        do {
            MealieAPI.shared.configure(baseURL: url)
            let info = try await MealieAPI.shared.getAppInfo()
            serverInfo = info
            showServerSetup = false
            serverURL = url
            isLoading = false
        } catch {
            logger.error("Server validation failed for \(url): \(error)")
            errorMessage = "Could not connect to server. Check the URL and try again."
            isLoading = false
        }
    }

    /// Trims whitespace and ensures an http(s) scheme. The scheme is matched case-insensitively
    /// (the keyboard may auto-capitalize "Https://") and lowercased; bare hosts get `https://`.
    nonisolated static func normalizeServerURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for scheme in ["https://", "http://"] where trimmed.lowercased().hasPrefix(scheme) {
            return scheme + trimmed.dropFirst(scheme.count)
        }
        return "https://\(trimmed)"
    }

    public func login() async {
        isLoading = true
        errorMessage = ""

        do {
            let token = try await MealieAPI.shared.login(email: email, password: password)
            MealieAPI.shared.accessToken = token.accessToken

            let user = try await MealieAPI.shared.getCurrentUser()
            currentUser = user

            AuthService.shared.saveSession(
                serverURL: serverURL,
                token: token.accessToken,
                userId: user.id,
                email: email,
                password: password
            )

            isAuthenticated = true
            isServerConnected = true
            isLoading = false
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                errorMessage = "Invalid email or password."
            case .serverError(_, let msg):
                errorMessage = "Server error: \(msg)"
            case .decodingError(let inner):
                errorMessage = "Login failed. Please try again."
                logger.error("Login decoding error: \(inner)")
            default:
                errorMessage = "Login failed. Please try again."
                logger.error("Login API error: \(error)")
            }
            isLoading = false
        } catch {
            errorMessage = "Connection failed. Check your network."
            logger.error("Login error: \(error)")
            isLoading = false
        }
    }

    public func loadCurrentUser() async {
        do {
            currentUser = try await MealieAPI.shared.getCurrentUser()
        } catch {
            logger.error("Failed to load user: \(error)")
        }
    }

    /// Soft logout: clears auth but preserves server URL and email for quick re-login.
    /// Used when the server returns 401 and token refresh fails.
    public func softLogout() {
        AuthService.shared.softClearSession()
        isAuthenticated = false
        isServerConnected = false
        serverURL = AuthService.shared.savedServerURL ?? ""
        email = AuthService.shared.savedEmail ?? ""
        password = ""
        showServerSetup = false // skip straight to login form
        currentUser = nil
    }

    public func selectSavedServer(_ server: SavedServer) {
        serverURL = server.url
        email = server.email
        showServerSetup = false
        errorMessage = ""
        Task { await validateServer() }
    }

    public func logout() {
        let wasLocal = isLocalMode
        AuthService.shared.clearSession()
        if !wasLocal {
            CacheService.shared.clearAll()
            OfflineRecipeStore.shared.clearAll()
            RecipeSyncService.shared.clearAll()
        }
        isAuthenticated = false
        isServerConnected = false
        showServerSetup = true
        currentUser = nil
        email = ""
        password = ""
        serverURL = ""
        savedServers = AuthService.shared.savedServers
    }
}
