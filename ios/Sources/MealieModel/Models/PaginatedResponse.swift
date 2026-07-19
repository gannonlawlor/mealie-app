import Foundation

public struct RecipePaginatedResponse: Codable, Sendable {
    public let page: Int
    public let perPage: Int
    public let total: Int
    public let totalPages: Int
    public let items: [RecipeSummary]

    enum CodingKeys: String, CodingKey {
        case page, total, items
        case perPage = "per_page"
        case totalPages = "total_pages"
    }
}

public struct CategoryPaginatedResponse: Codable, Sendable {
    public let page: Int
    public let perPage: Int
    public let total: Int
    public let totalPages: Int
    public let items: [RecipeCategory]

    enum CodingKeys: String, CodingKey {
        case page, total, items
        case perPage = "per_page"
        case totalPages = "total_pages"
    }
}

public struct TagPaginatedResponse: Codable, Sendable {
    public let page: Int
    public let perPage: Int
    public let total: Int
    public let totalPages: Int
    public let items: [RecipeTag]

    enum CodingKeys: String, CodingKey {
        case page, total, items
        case perPage = "per_page"
        case totalPages = "total_pages"
    }
}

public struct MealPlanPaginatedResponse: Codable, Sendable {
    public let page: Int
    public let perPage: Int
    public let total: Int
    public let totalPages: Int
    public let items: [MealPlanEntry]

    enum CodingKeys: String, CodingKey {
        case page, total, items
        case perPage = "per_page"
        case totalPages = "total_pages"
    }
}

public struct ShoppingListPaginatedResponse: Codable, Sendable {
    public let page: Int
    public let perPage: Int
    public let total: Int
    public let totalPages: Int
    public let items: [ShoppingList]

    enum CodingKeys: String, CodingKey {
        case page, total, items
        case perPage = "per_page"
        case totalPages = "total_pages"
    }
}
