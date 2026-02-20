import Foundation
import Observation
import SkipFuse

@MainActor @Observable public class AuthViewModel {
    public var serverURL: String = ""
    public var email: String = ""
    public var password: String = ""
    public var isLoading: Bool = false
    public var errorMessage: String = ""
    public var isAuthenticated: Bool = false
    public var currentUser: User? = nil
    public var serverInfo: AppInfo? = nil
    public var showServerSetup: Bool = true

    public init() {
        if AuthService.shared.restoreSession() {
            isAuthenticated = true
            showServerSetup = false
            serverURL = AuthService.shared.savedServerURL ?? ""
        }
    }

    public func validateServer() async {
        isLoading = true
        errorMessage = ""

        let url = serverURL.hasPrefix("http") ? serverURL : "https://\(serverURL)"

        do {
            MealieAPI.shared.configure(baseURL: url)
            let info = try await MealieAPI.shared.getAppInfo()
            serverInfo = info
            showServerSetup = false
            serverURL = url
            isLoading = false
        } catch {
            errorMessage = "Could not connect to server. Check the URL and try again."
            isLoading = false
        }
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
                userId: user.id
            )

            isAuthenticated = true
            isLoading = false
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                errorMessage = "Invalid email or password."
            case .serverError(_, let msg):
                errorMessage = "Server error: \(msg)"
            default:
                errorMessage = "Login failed. Please try again."
            }
            isLoading = false
        } catch {
            errorMessage = "Connection failed. Check your network."
            isLoading = false
        }
    }

    public func loadCurrentUser() async {
        do {
            currentUser = try await MealieAPI.shared.getCurrentUser()
        } catch {
            print("Failed to load user: \(error)")
        }
    }

    public func logout() {
        AuthService.shared.clearSession()
        isAuthenticated = false
        showServerSetup = true
        currentUser = nil
        email = ""
        password = ""
        serverURL = ""
    }
}
