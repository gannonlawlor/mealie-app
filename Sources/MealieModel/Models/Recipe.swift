import Foundation

public struct Recipe: Codable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let slug: String?
    public let name: String?
    public let description: String?
    public let image: String?
    public let recipeCategory: [RecipeCategory]?
    public let tags: [RecipeTag]?
    public let tools: [RecipeTool]?
    public let rating: Int?
    public let recipeYield: String?
    public let recipeIngredient: [RecipeIngredient]?
    public let recipeInstructions: [RecipeInstruction]?
    public let totalTime: String?
    public let prepTime: String?
    public let performTime: String?
    public let nutrition: Nutrition?
    public let settings: RecipeSettings?
    public let dateAdded: String?
    public let dateUpdated: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let orgURL: String?
    public let extras: [String: String]?

    public init(id: String?, slug: String?, name: String?, description: String?, image: String?, recipeCategory: [RecipeCategory]?, tags: [RecipeTag]?, tools: [RecipeTool]?, rating: Int?, recipeYield: String?, recipeIngredient: [RecipeIngredient]?, recipeInstructions: [RecipeInstruction]?, totalTime: String?, prepTime: String?, performTime: String?, nutrition: Nutrition?, settings: RecipeSettings?, dateAdded: String?, dateUpdated: String?, createdAt: String?, updatedAt: String?, orgURL: String?, extras: [String: String]?) {
        self.id = id; self.slug = slug; self.name = name; self.description = description; self.image = image
        self.recipeCategory = recipeCategory; self.tags = tags; self.tools = tools; self.rating = rating
        self.recipeYield = recipeYield; self.recipeIngredient = recipeIngredient
        self.recipeInstructions = recipeInstructions; self.totalTime = totalTime; self.prepTime = prepTime
        self.performTime = performTime; self.nutrition = nutrition; self.settings = settings
        self.dateAdded = dateAdded; self.dateUpdated = dateUpdated; self.createdAt = createdAt
        self.updatedAt = updatedAt; self.orgURL = orgURL; self.extras = extras
    }

    enum CodingKeys: String, CodingKey {
        case id, slug, name, description, image, tags, tools, rating, nutrition, settings, extras
        case recipeCategory = "recipe_category"
        case recipeYield = "recipe_yield"
        case recipeIngredient = "recipe_ingredient"
        case recipeInstructions = "recipe_instructions"
        case totalTime = "total_time"
        case prepTime = "prep_time"
        case performTime = "perform_time"
        case dateAdded = "date_added"
        case dateUpdated = "date_updated"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case orgURL = "org_url"
    }

    public static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct RecipeSummary: Codable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let slug: String?
    public let name: String?
    public let description: String?
    public let image: String?
    public let recipeCategory: [RecipeCategory]?
    public let tags: [RecipeTag]?
    public let rating: Int?
    public let dateAdded: String?
    public let dateUpdated: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, description, image, tags, rating
        case recipeCategory = "recipe_category"
        case dateAdded = "date_added"
        case dateUpdated = "date_updated"
    }

    public static func == (lhs: RecipeSummary, rhs: RecipeSummary) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct RecipeCategory: Codable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let name: String?
    public let slug: String?
}

public struct RecipeTag: Codable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let name: String?
    public let slug: String?
}

public struct RecipeTool: Codable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let name: String?
    public let slug: String?
    public let onHand: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, slug
        case onHand = "on_hand"
    }
}

public struct RecipeIngredient: Codable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let quantity: Double?
    public let unit: IngredientUnit?
    public let food: IngredientFood?
    public let note: String?
    public let isFood: Bool?
    public let disableAmount: Bool?
    public let display: String?
    public let title: String?
    public let originalText: String?
    public let referenceId: String?

    public init(id: String?, quantity: Double?, unit: IngredientUnit?, food: IngredientFood?, note: String?, isFood: Bool?, disableAmount: Bool?, display: String?, title: String?, originalText: String?, referenceId: String?) {
        self.id = id; self.quantity = quantity; self.unit = unit; self.food = food; self.note = note
        self.isFood = isFood; self.disableAmount = disableAmount; self.display = display
        self.title = title; self.originalText = originalText; self.referenceId = referenceId
    }

    enum CodingKeys: String, CodingKey {
        case id, quantity, unit, food, note, display, title
        case isFood = "is_food"
        case disableAmount = "disable_amount"
        case originalText = "original_text"
        case referenceId = "reference_id"
    }

    public var displayText: String {
        if let display = display, !display.isEmpty { return display }
        var parts: [String] = []
        if let q = quantity, q > 0 {
            parts.append(q.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(q)) : String(q))
        }
        if let u = unit?.name, !u.isEmpty { parts.append(u) }
        if let f = food?.name, !f.isEmpty { parts.append(f) }
        if let n = note, !n.isEmpty { parts.append(n) }
        return parts.joined(separator: " ")
    }
}

public struct IngredientUnit: Codable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let name: String?
    public let abbreviation: String?
    public let description: String?
}

public struct IngredientFood: Codable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let name: String?
    public let description: String?
    public let labelId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case labelId = "label_id"
    }
}

public struct RecipeInstruction: Codable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let title: String?
    public let text: String?
    public let ingredientReferences: [String]?

    public init(id: String?, title: String?, text: String?, ingredientReferences: [String]?) {
        self.id = id; self.title = title; self.text = text; self.ingredientReferences = ingredientReferences
    }

    enum CodingKeys: String, CodingKey {
        case id, title, text
        case ingredientReferences = "ingredient_references"
    }
}

public struct Nutrition: Codable, Sendable, Hashable {
    public let calories: String?
    public let fatContent: String?
    public let proteinContent: String?
    public let carbohydrateContent: String?
    public let fiberContent: String?
    public let sodiumContent: String?
    public let sugarContent: String?

    enum CodingKeys: String, CodingKey {
        case calories
        case fatContent = "fat_content"
        case proteinContent = "protein_content"
        case carbohydrateContent = "carbohydrate_content"
        case fiberContent = "fiber_content"
        case sodiumContent = "sodium_content"
        case sugarContent = "sugar_content"
    }
}

public struct RecipeSettings: Codable, Sendable, Hashable {
    public let isPublic: Bool?
    public let showNutrition: Bool?
    public let showAssets: Bool?
    public let landscapeView: Bool?
    public let disableComments: Bool?
    public let disableAmount: Bool?

    enum CodingKeys: String, CodingKey {
        case isPublic = "public"
        case showNutrition = "show_nutrition"
        case showAssets = "show_assets"
        case landscapeView = "landscape_view"
        case disableComments = "disable_comments"
        case disableAmount = "disable_amount"
    }
}

public struct CreateRecipe: Codable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct CreateRecipeFromURL: Codable, Sendable {
    public let url: String
    public let includeTags: Bool

    public init(url: String, includeTags: Bool = true) {
        self.url = url
        self.includeTags = includeTags
    }

    enum CodingKeys: String, CodingKey {
        case url
        case includeTags = "include_tags"
    }
}
