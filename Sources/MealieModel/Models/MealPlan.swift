import Foundation

public struct MealPlanEntry: Codable, Sendable, Identifiable, Hashable {
    public let id: Int?
    public let date: String?
    public let entryType: String?
    public let title: String?
    public let text: String?
    public let recipeId: String?
    public let recipe: RecipeSummary?
    public let groupId: String?
    public let householdId: String?

    public static func == (lhs: MealPlanEntry, rhs: MealPlanEntry) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var displayTitle: String {
        if let recipeName = recipe?.name, !recipeName.isEmpty { return recipeName }
        if let title = title, !title.isEmpty { return title }
        return "Meal"
    }

    public var mealType: MealType {
        MealType(rawValue: entryType ?? "") ?? .dinner
    }
}

public enum MealType: String, Codable, Sendable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack = "side"

    public var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    public var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "cup.and.saucer"
        }
    }
}

public struct CreateMealPlan: Codable, Sendable {
    public let date: String
    public let entryType: String
    public let title: String
    public let text: String
    public let recipeId: String?

    public init(date: String, entryType: String, title: String = "", text: String = "", recipeId: String? = nil) {
        self.date = date
        self.entryType = entryType
        self.title = title
        self.text = text
        self.recipeId = recipeId
    }
}
