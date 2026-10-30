import XCTest
@testable import MealieModel

final class SessionIntegrityTests: XCTestCase {
    private var originalURL = ""
    private var originalToken = ""

    override func setUp() {
        super.setUp()
        originalURL = MealieAPI.shared.baseURL
        originalToken = MealieAPI.shared.accessToken
    }

    override func tearDown() {
        MealieAPI.shared.configure(baseURL: originalURL, token: originalToken)
        super.tearDown()
    }

    private final class Vault: CredentialVault {
        var values: [String: String] = [:]
        var failingKey: String?
        func read(_ key: String) throws -> String? { values[key] }
        func write(_ value: String?, for key: String) throws {
            if key == failingKey { throw KeychainCredentialVault.VaultError.invalidData }
            values[key] = value
        }
    }

    private final class UnsynchronizedDefaults: UserDefaults, @unchecked Sendable {
        var synchronizeCalls = 0
        override func synchronize() -> Bool {
            synchronizeCalls += 1
            return false
        }
    }

    func testSignInDoesNotDependOnObsoleteDefaultsSynchronization() throws {
        let suite = "SessionIntegrityTests." + UUID().uuidString
        let defaults = UnsynchronizedDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vault = Vault()
        let credentials = SecureCredentialStore(vault: vault, legacy: [defaults])
        let auth = AuthService(store: defaults, credentials: credentials)

        try auth.saveSession(serverURL: "https://recipes.example", token: "token", userId: "user",
                             email: "cook@example.com", password: "password")

        XCTAssertEqual(defaults.synchronizeCalls, 0)
        let restarted = AuthService(store: defaults, credentials: credentials)
        XCTAssertTrue(restarted.restoreSession())
        XCTAssertEqual(restarted.savedToken, "token")
        XCTAssertEqual(restarted.savedPassword, "password")
        XCTAssertNil(defaults.string(forKey: "mealie_access_token"))
        XCTAssertNil(defaults.string(forKey: "mealie_password"))
    }

    func testFailedSessionReplacementNeverRestoresMixedServerCredentials() throws {
        for key in ["mealie_access_token", "mealie_password"] {
            let suite = "SessionIntegrityTests." + UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let vault = Vault()
            let credentials = SecureCredentialStore(vault: vault, legacy: [defaults])
            let auth = AuthService(store: defaults, credentials: credentials)
            try auth.saveSession(serverURL: "https://old.example", token: "old-token", userId: "old", email: "old@example", password: "old-password")
            vault.failingKey = key
            XCTAssertThrowsError(try auth.saveSession(serverURL: "https://new.example", token: "new-token", userId: "new", email: "new@example", password: "new-password"))
            let restarted = AuthService(store: defaults, credentials: credentials)
            XCTAssertFalse(restarted.restoreSession(), key)
            XCTAssertNil(restarted.savedToken, key)
            XCTAssertNil(restarted.savedPassword, key)
            vault.failingKey = nil
            try restarted.saveSession(serverURL: "https://new.example", token: "new-token", userId: "new", email: "new@example", password: "new-password")
            XCTAssertEqual(restarted.savedServerURL, "https://new.example")
            XCTAssertEqual(restarted.savedToken, "new-token")
            XCTAssertEqual(restarted.savedPassword, "new-password")
        }
    }

    func testLegacySessionWithoutMarkerRemainsReadable() throws {
        let suite = "SessionIntegrityTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("https://old.example", forKey: "mealie_server_url")
        defaults.set("old-token", forKey: "mealie_access_token")
        let auth = AuthService(store: defaults, credentials: SecureCredentialStore(vault: Vault(), legacy: [defaults]))
        XCTAssertEqual(auth.savedToken, "old-token")
        XCTAssertNil(defaults.string(forKey: "mealie_access_token"))
    }
}
