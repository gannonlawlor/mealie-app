import XCTest
@testable import MealieModel

final class ServerURLNormalizationTests: XCTestCase {

    func testBareHostGetsHTTPS() {
        XCTAssertEqual(AuthViewModel.normalizeServerURL("a.example"), "https://a.example")
    }

    func testWhitespaceIsTrimmed() {
        XCTAssertEqual(AuthViewModel.normalizeServerURL("  a.example\n"), "https://a.example")
    }

    func testAutoCapitalizedSchemeIsLowercased() {
        XCTAssertEqual(AuthViewModel.normalizeServerURL("Https://a.example"), "https://a.example")
        XCTAssertEqual(AuthViewModel.normalizeServerURL("HTTPS://a.example"), "https://a.example")
    }

    func testExplicitHTTPIsKept() {
        XCTAssertEqual(AuthViewModel.normalizeServerURL("Http://10.0.0.2:9000"), "http://10.0.0.2:9000")
    }

    /// A host that merely starts with "http" still needs a scheme.
    func testHostStartingWithHTTPGetsScheme() {
        XCTAssertEqual(AuthViewModel.normalizeServerURL("httpbin.example"), "https://httpbin.example")
    }
}
