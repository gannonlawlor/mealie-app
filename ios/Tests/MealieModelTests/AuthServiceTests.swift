import XCTest
import Foundation
@testable import MealieModel

final class AuthServiceTests: XCTestCase {

    private let savedServersKey = "mealie_saved_servers"
    private var originalData: Data?

    /// AuthService persists into the App Group container (shared with the
    /// Share Extension), so the tests have to reset that same store.
    private var store: UserDefaults { AuthService.shared.store }

    override func setUp() {
        super.setUp()
        originalData = store.data(forKey: savedServersKey)
        store.removeObject(forKey: savedServersKey)
    }

    override func tearDown() {
        if let originalData {
            store.set(originalData, forKey: savedServersKey)
        } else {
            store.removeObject(forKey: savedServersKey)
        }
        super.tearDown()
    }

    func testAddSavedServerInsertsAtFront() {
        AuthService.shared.addSavedServer(url: "https://a.example.com", email: "a@example.com")
        AuthService.shared.addSavedServer(url: "https://b.example.com", email: "b@example.com")

        let servers = AuthService.shared.savedServers
        XCTAssertEqual(servers.count, 2)
        XCTAssertEqual(servers.first, SavedServer(url: "https://b.example.com", email: "b@example.com"))
        XCTAssertEqual(servers.last, SavedServer(url: "https://a.example.com", email: "a@example.com"))
    }

    func testAddSavedServerDeduplicatesByURL() {
        AuthService.shared.addSavedServer(url: "https://a.example.com", email: "old@example.com")
        AuthService.shared.addSavedServer(url: "https://b.example.com", email: "b@example.com")
        AuthService.shared.addSavedServer(url: "https://a.example.com", email: "new@example.com")

        let servers = AuthService.shared.savedServers
        XCTAssertEqual(servers.count, 2)
        XCTAssertEqual(servers.first, SavedServer(url: "https://a.example.com", email: "new@example.com"))
    }

    func testAddSavedServerCapsAtFive() {
        for i in 1...7 {
            AuthService.shared.addSavedServer(url: "https://server\(i).example.com", email: "u\(i)@example.com")
        }

        let servers = AuthService.shared.savedServers
        XCTAssertEqual(servers.count, 5)
        XCTAssertEqual(servers.first?.url, "https://server7.example.com")
        XCTAssertEqual(servers.last?.url, "https://server3.example.com")
    }

    func testRemoveSavedServer() {
        AuthService.shared.addSavedServer(url: "https://a.example.com", email: "a@example.com")
        AuthService.shared.addSavedServer(url: "https://b.example.com", email: "b@example.com")

        AuthService.shared.removeSavedServer(url: "https://a.example.com")

        let servers = AuthService.shared.savedServers
        XCTAssertEqual(servers, [SavedServer(url: "https://b.example.com", email: "b@example.com")])
    }
}
