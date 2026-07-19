import Foundation

public struct User: Codable, Sendable, Identifiable {
    public let id: String
    public let username: String?
    public let fullName: String?
    public let email: String?
    public let admin: Bool?
    public let group: String?
    public let household: String?
    public let groupId: String?
    public let householdId: String?
    public let tokens: [APIToken]?
    public let canInvite: Bool?
    public let canManage: Bool?
    public let canOrganize: Bool?
    public let favoriteRecipes: [String]?
}

public struct UserFavorites: Codable, Sendable {
    public let favoriteRecipes: [String]?
}
