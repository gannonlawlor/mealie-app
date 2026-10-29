import XCTest
@testable import MealieModel

final class SecureCredentialStoreTests: XCTestCase {
    private final class Vault: CredentialVault {
        var values: [String: String] = [:]
        var failWrites = false
        func read(_ key: String) throws -> String? { values[key] }
        func write(_ value: String?, for key: String) throws {
            if failWrites { throw NSError(domain: "TestVault", code: 1) }
            values[key] = value
        }
    }
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() {
        suite = "SecureCredentialStoreTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
    }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    func testMigratesOnlyAfterSuccessfulWrite() throws {
        defaults.set("old", forKey: "token")
        let vault = Vault()
        vault.failWrites = true
        let store = SecureCredentialStore(vault: vault, legacy: [defaults])
        XCTAssertThrowsError(try store.read("token"))
        XCTAssertEqual(defaults.string(forKey: "token"), "old")
        vault.failWrites = false
        XCTAssertEqual(try store.read("token"), "old")
        XCTAssertNil(defaults.string(forKey: "token"))
    }

    func testSecureValueWinsAndCleansLegacyCopies() throws {
        defaults.set("old", forKey: "token")
        let vault = Vault()
        vault.values["token"] = "new"
        let store = SecureCredentialStore(vault: vault, legacy: [defaults])
        XCTAssertEqual(try store.read("token"), "new")
        XCTAssertNil(defaults.string(forKey: "token"))
    }

    func testFailedNewWriteNeverStoresPlaintext() {
        let vault = Vault()
        vault.failWrites = true
        let store = SecureCredentialStore(vault: vault, legacy: [defaults])
        XCTAssertThrowsError(try store.write("secret", for: "token"))
        XCTAssertNil(defaults.string(forKey: "token"))
    }

    func testLogoutCannotResurrectCredentialWhenDeletionFails() throws {
        let vault = Vault()
        vault.values["token"] = "old"
        vault.failWrites = true
        let store = SecureCredentialStore(vault: vault, legacy: [defaults])
        XCTAssertThrowsError(try store.write(nil, for: "token"))
        XCTAssertThrowsError(try store.read("token"))
        vault.failWrites = false
        XCTAssertNil(try store.read("token"))
        XCTAssertNil(vault.values["token"])
        try store.write("new", for: "token")
        XCTAssertEqual(try store.read("token"), "new")
    }
}
