import Foundation
import XCTest
@testable import MealieModel

final class FormURLEncoderTests: XCTestCase {
    func testCredentialsCannotIntroduceFieldsOrTurnPlusIntoSpace() {
        let data = FormURLEncoder.encode([
            ("username", "cook+recipes@example.com"),
            ("password", "salt&pepper=50% +")
        ])
        XCTAssertEqual(String(decoding: data, as: UTF8.self),
                       "username=cook%2Brecipes%40example.com&password=salt%26pepper%3D50%25+%2B")
    }

    func testUnicodeUsesUTF8PercentEncoding() {
        XCTAssertEqual(String(decoding: FormURLEncoder.encode([("password", "café🍲")]), as: UTF8.self),
                       "password=caf%C3%A9%F0%9F%8D%B2")
    }

    func testEmptyValuesAndSafeCharacters() {
        XCTAssertEqual(String(decoding: FormURLEncoder.encode([("username", ""), ("password", "AZaz09*-._")]), as: UTF8.self),
                       "username=&password=AZaz09*-._")
    }

    func testLoginRequestUsesFormEncoding() throws {
        let api = MealieAPI.shared
        let originalURL = api.baseURL
        let originalToken = api.accessToken
        defer { api.configure(baseURL: originalURL, token: originalToken) }
        api.configure(baseURL: "https://recipes.example")
        let request = try api.loginRequest(email: "a+b@example.com", password: "a&b")
        XCTAssertEqual(request.url?.absoluteString, "https://recipes.example/api/auth/token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(request.httpBody, Data("username=a%2Bb%40example.com&password=a%26b".utf8))
    }
}
