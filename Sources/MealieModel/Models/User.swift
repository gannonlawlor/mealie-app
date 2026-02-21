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

    enum CodingKeys: String, CodingKey {
        case id, username, email, admin, group, household, tokens
        case fullName = "full_name"
        case groupId = "group_id"
        case householdId = "household_id"
        case canInvite = "can_invite"
        case canManage = "can_manage"
        case canOrganize = "can_organize"
        case favoriteRecipes = "favorite_recipes"
    }
}

public struct UserFavorites: Codable, Sendable {
    public let favoriteRecipes: [String]?

    enum CodingKeys: String, CodingKey {
        case favoriteRecipes = "favorite_recipes"
    }
}
