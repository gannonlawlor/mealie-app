import Foundation
import Security
import XCTest
@testable import MealieModel

private final class AuthURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> (Int, String)
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?
    private var responseTask: Task<Void, Never>?

    static func install(_ handler: Handler?) {
        lock.withLock { self.handler = handler }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let handler = Self.lock.withLock { Self.handler! }
        responseTask = Task {
            do {
                let (status, body) = try await handler(request)
                guard !Task.isCancelled else { return }
                let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                               httpVersion: nil, headerFields: nil)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(body.utf8))
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }
    override func stopLoading() { responseTask?.cancel() }
}

private actor ResponseGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false
    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}

final class AuthRecoveryTests: XCTestCase {
    private final class Vault: CredentialVault {
        var values: [String: String] = [:]
        var writeError: KeychainCredentialVault.VaultError?
        func read(_ key: String) throws -> String? { values[key] }
        func write(_ value: String?, for key: String) throws {
            if let writeError { throw writeError }
            values[key] = value
        }
    }
    private var originalURL = ""
    private var originalToken = ""
    private var suite = ""
    private var defaults: UserDefaults!
    private var auth: AuthService!
    private var api: MealieAPI!
    private var session: URLSession!
    private var vault: Vault!

    override func setUpWithError() throws {
        originalURL = MealieAPI.shared.baseURL
        originalToken = MealieAPI.shared.accessToken
        suite = "AuthRecoveryTests.\(UUID())"
        defaults = UserDefaults(suiteName: suite)!
        vault = Vault()
        auth = AuthService(store: defaults, credentials: SecureCredentialStore(vault: vault, legacy: [defaults]))
        try auth.saveSession(serverURL: "https://recipes.example", token: "expired", userId: "user",
                             email: "cook@example.com", password: "old-password")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocol.self]
        session = URLSession(configuration: configuration)
        api = MealieAPI(session: session, authService: auth)
        api.configure(baseURL: "https://recipes.example", token: "expired")
    }
    override func tearDown() {
        session.invalidateAndCancel()
        AuthURLProtocol.install(nil)
        defaults.removePersistentDomain(forName: suite)
        MealieAPI.shared.configure(baseURL: originalURL, token: originalToken)
    }

    @MainActor
    func testExpiredSessionClearsSpinnerAndRelaunchAllowsSignIn() async {
        AuthURLProtocol.install { _ in (401, "{}") }
        let vm = AuthViewModel(authService: auth, api: api)
        api.onUnauthorized = { vm.softLogout() }
        vm.isLoading = true
        await vm.loadCurrentUser()
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isServerConnected)
        XCTAssertFalse(vm.showServerSetup)
        XCTAssertEqual(vm.email, "cook@example.com")
        XCTAssertEqual(vm.password, "")
        XCTAssertTrue(vm.errorMessage.contains("expired"))
        XCTAssertNil(auth.savedToken)
        XCTAssertNil(auth.savedPassword)
        let restarted = AuthViewModel(authService: auth, api: api)
        XCTAssertFalse(restarted.isLoading)
        XCTAssertFalse(restarted.isAuthenticated)
        XCTAssertFalse(restarted.showServerSetup)
        XCTAssertEqual(restarted.email, "cook@example.com")
        XCTAssertEqual(api.accessToken, "")
        AuthURLProtocol.install { request in
            if request.url!.path == "/api/auth/token" {
                return (200, #"{"access_token":"new-token","token_type":"bearer"}"#)
            }
            return (200, #"{"id":"user"}"#)
        }
        restarted.password = "new-password"
        await restarted.login()
        XCTAssertFalse(restarted.isLoading)
        XCTAssertTrue(restarted.isServerConnected)
        XCTAssertEqual(auth.savedToken, "new-token")
    }

    @MainActor
    func testRejectedManualLoginDoesNotRefreshOrClearForm() async {
        AuthURLProtocol.install { request in
            XCTAssertEqual(request.url!.path, "/api/auth/token")
            return (401, "{}")
        }
        let vm = AuthViewModel(authService: auth, api: api)
        api.onUnauthorized = { XCTFail("Manual login must not expire a session") }
        vm.password = "incorrect"
        await vm.login()
        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.password, "incorrect")
        XCTAssertEqual(vm.errorMessage, "Invalid email or password.")
    }

    @MainActor
    func testConcurrentUnauthorizedRequestsShareRefresh() async throws {
        let refreshStarted = expectation(description: "Refresh started")
        let secondRejected = expectation(description: "Second expired request rejected")
        let refreshGate = ResponseGate()
        AuthURLProtocol.install { request in
            if request.url!.path == "/api/auth/refresh" {
                refreshStarted.fulfill()
                await refreshGate.wait()
                return (200, #"{"access_token":"fresh","token_type":"bearer"}"#)
            }
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired" {
                if request.url!.path == "/raw" { secondRejected.fulfill() }
                return (401, "{}")
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fresh")
            return (200, #"{"id":"user"}"#)
        }
        let unexpectedLogout = expectation(description: "No logout during refresh")
        unexpectedLogout.isInverted = true
        api.onUnauthorized = { unexpectedLogout.fulfill() }
        let client = api!
        let first = Task { try await client.getCurrentUser() }
        await fulfillment(of: [refreshStarted], timeout: 3)
        let rawRequest = try client.buildRequest(method: "GET", path: "/raw")
        let second = Task { try await client.performRaw(rawRequest) }
        await fulfillment(of: [secondRejected], timeout: 3)
        await fulfillment(of: [unexpectedLogout], timeout: 0.2)
        await refreshGate.release()
        let user = try await first.value
        let (_, response) = try await second.value
        XCTAssertEqual(user.id, "user")
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(auth.savedToken, "fresh")
    }

    @MainActor
    func testChangingServerClearsSpinnerAndIgnoresLateLogin() async {
        let started = expectation(description: "Login started")
        let gate = ResponseGate()
        AuthURLProtocol.install { _ in
            started.fulfill()
            await gate.wait()
            return (200, #"{"access_token":"late-token","token_type":"bearer"}"#)
        }
        auth.softClearSession()
        let vm = AuthViewModel(authService: auth, api: api)
        vm.password = "password"
        let login = Task { await vm.login() }
        await fulfillment(of: [started], timeout: 3)
        XCTAssertTrue(vm.isLoading)
        vm.changeServer()
        XCTAssertFalse(vm.isLoading)
        await gate.release()
        await login.value
        XCTAssertTrue(vm.showServerSetup)
        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertNil(auth.savedToken)
        XCTAssertEqual(api.accessToken, "")
    }

    @MainActor
    func testNetworkTimeoutReleasesLoginButton() async {
        AuthURLProtocol.install { request in
            XCTAssertEqual(request.timeoutInterval, 30)
            throw URLError(.timedOut)
        }
        let vm = AuthViewModel(authService: auth, api: api)
        vm.password = "password"
        await vm.login()
        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.errorMessage, "Connection failed. Check your network.")
    }

    @MainActor
    func testKeychainFailureShowsActionableErrorAndAllowsRetry() async {
        AuthURLProtocol.install { request in
            if request.url!.path == "/api/auth/token" {
                return (200, #"{"access_token":"new-token","token_type":"bearer"}"#)
            }
            return (200, #"{"id":"user"}"#)
        }
        for status in [errSecInteractionNotAllowed, errSecMissingEntitlement, errSecNotAvailable] {
            auth.softClearSession()
            let vm = AuthViewModel(authService: auth, api: api)
            vm.password = "password"
            vault.writeError = .status(status)
            await vm.login()

            XCTAssertFalse(vm.isLoading)
            XCTAssertFalse(vm.isAuthenticated)
            XCTAssertFalse(vm.isServerConnected)
            XCTAssertNil(vm.currentUser)
            XCTAssertNil(auth.savedToken)
            XCTAssertEqual(api.accessToken, "")
            XCTAssertEqual(api.baseURL, "https://recipes.example")
            XCTAssertEqual(vm.email, "cook@example.com")
            XCTAssertEqual(vm.password, "password")
            XCTAssertEqual(vm.errorMessage.contains("Unlock"), status == errSecInteractionNotAllowed)
            if status != errSecInteractionNotAllowed {
                XCTAssertTrue(vm.errorMessage.contains(String(status)))
            }

            vault.writeError = nil
            await vm.login()
            XCTAssertTrue(vm.isServerConnected)
            XCTAssertFalse(vm.isLoading)
            XCTAssertEqual(auth.savedToken, "new-token")
        }
    }
}
