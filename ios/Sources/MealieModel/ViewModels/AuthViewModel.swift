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
        authService.savedAppMode == .local
    }

    private let authService: AuthService
    private let api: MealieAPI
    private var operationID = UUID()

    public convenience init() {
        self.init(authService: .shared, api: .shared)
    }

    init(authService: AuthService, api: MealieAPI) {
        self.authService = authService
        self.api = api
        serverURL = authService.savedServerURL ?? ""
        email = authService.savedEmail ?? ""
        savedServers = authService.savedServers
        if authService.savedAppMode == .local {
            isAuthenticated = true
            showServerSetup = false
        } else if authService.restoreSession() {
            isAuthenticated = true
            isServerConnected = true
            showServerSetup = false
            api.configure(baseURL: serverURL, token: authService.savedToken ?? "")
        } else if !serverURL.isEmpty {
            api.configure(baseURL: serverURL)
            showServerSetup = false
        }
    }

    /// Invalidate work from a dismissed form or expired session. Late responses
    /// must not re-enable an old session or change the next form's loading state.
    public func cancelPendingAuthentication() {
        operationID = UUID()
        isLoading = false
    }

    public func changeServer() {
        cancelPendingAuthentication()
        showServerSetup = true
        errorMessage = ""
        serverInfo = nil
    }

    public func enterLocalMode() {
        cancelPendingAuthentication()
        authService.startLocalMode()
        isAuthenticated = true
        showServerSetup = false
    }

    public func validateServer() async {
        guard !isLoading else { return }
        let operation = UUID()
        operationID = operation
        isLoading = true
        errorMessage = ""
        defer { if operationID == operation { isLoading = false } }

        let url = Self.normalizeServerURL(serverURL)

        do {
            api.configure(baseURL: url)
            let info = try await api.getAppInfo()
            guard operationID == operation, !Task.isCancelled else { return }
            serverInfo = info
            showServerSetup = false
            serverURL = url
        } catch {
            guard operationID == operation, !Task.isCancelled else { return }
            logger.error("Server validation failed for \(url): \(error)")
            errorMessage = "Could not connect to server. Check the URL and try again."
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
        guard !isLoading else { return }
        let operation = UUID()
        operationID = operation
        isLoading = true
        errorMessage = ""
        defer { if operationID == operation { isLoading = false } }

        let server = serverURL
        let loginEmail = email
        let loginPassword = password
        api.configure(baseURL: server)
        do {
            let token = try await api.login(email: loginEmail, password: loginPassword)
            guard operationID == operation, !Task.isCancelled else { return }
            api.accessToken = token.accessToken

            let user = try await api.getCurrentUser()
            guard operationID == operation, !Task.isCancelled else { return }
            try authService.saveSession(
                serverURL: server,
                token: token.accessToken,
                userId: user.id,
                email: loginEmail,
                password: loginPassword
            )
            currentUser = user

            isAuthenticated = true
            isServerConnected = true
        } catch let error as KeychainCredentialVault.VaultError {
            guard operationID == operation, !Task.isCancelled else { return }
            api.configure(baseURL: server)
            currentUser = nil
            isAuthenticated = false
            isServerConnected = false
            errorMessage = error.signInMessage
            logger.error("Secure sign-in storage failed: \(error.localizedDescription)")
        } catch let error as APIError {
            guard operationID == operation, !Task.isCancelled else { return }
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
        } catch {
            guard operationID == operation, !Task.isCancelled else { return }
            errorMessage = "Connection failed. Check your network."
            logger.error("Login error: \(error)")
        }
    }

    public func loadCurrentUser() async {
        do {
            currentUser = try await api.getCurrentUser()
        } catch {
            logger.error("Failed to load user: \(error)")
        }
    }

    /// Soft logout: clears auth but preserves server URL and email for quick re-login.
    /// Used when the server returns 401 and token refresh fails.
    public func softLogout() {
        cancelPendingAuthentication()
        authService.softClearSession()
        api.configure(baseURL: authService.savedServerURL ?? "")
        errorMessage = "Your session has expired. Please sign in again."
        isAuthenticated = false
        isServerConnected = false
        serverURL = authService.savedServerURL ?? ""
        email = authService.savedEmail ?? ""
        password = ""
        showServerSetup = false // skip straight to login form
        currentUser = nil
    }

    public func selectSavedServer(_ server: SavedServer) {
        cancelPendingAuthentication()
        serverURL = server.url
        email = server.email
        showServerSetup = false
        errorMessage = ""
        Task { await validateServer() }
    }

    public func logout() {
        cancelPendingAuthentication()
        let wasLocal = isLocalMode
        authService.clearSession()
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
        savedServers = authService.savedServers
    }
}
