import Foundation

public struct AuthToken: Codable, Sendable {
    public let accessToken: String
    public let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

public struct APIToken: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let createdAt: String?
}

public struct AppInfo: Codable, Sendable {
    public let version: String
    public let demoStatus: Bool?
    public let allowSignup: Bool?
    public let enableOidc: Bool?
}
