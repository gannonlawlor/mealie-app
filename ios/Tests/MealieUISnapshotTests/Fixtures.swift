import Foundation
@testable import MealieModel

/// Deterministic fixture data for snapshot tests.
///
/// Everything here is fully static: no network, no current-date dependence.
/// The meal-plan week is pinned to a week in the past (Mon 2025-03-10) so that
/// `Calendar.current.isDateInToday(_:)` can never highlight a "today" cell.
enum Fixtures {

    // MARK: - Categories & Tags

    static let categories: [RecipeCategory] = [
        RecipeCategory(id: "cat-dinner", name: "Dinner", slug: "dinner"),
        RecipeCategory(id: "cat-italian", name: "Italian", slug: "italian"),
    ]

    static let tags: [RecipeTag] = [
        RecipeTag(id: "tag-comfort", name: "Comfort Food", slug: "comfort-food"),
        RecipeTag(id: "tag-weeknight", name: "Weeknight", slug: "weeknight"),
    ]

    // MARK: - Recipe detail

    static func ingredient(_ display: String, title: String? = nil) -> RecipeIngredient {
        RecipeIngredient(
            quantity: nil, unit: nil, food: nil, note: nil,
            isFood: false, disableAmount: true,
            display: display, title: title,
            originalText: nil, referenceId: nil
        )
    }

    static let ingredients: [RecipeIngredient] = [
        ingredient("400 g spaghetti", title: "Pasta"),
        ingredient("2 tbsp olive oil"),
        ingredient("150 g pancetta, diced"),
        ingredient("4 egg yolks", title: "Sauce"),
        ingredient("50 g pecorino romano, grated"),
        ingredient("freshly ground black pepper"),
    ]

    static let instructions: [RecipeInstruction] = [
        RecipeInstruction(
            id: "step-1", title: nil,
            text: "Bring a large pot of salted water to a boil and cook the spaghetti until al dente.",
            ingredientReferences: nil
        ),
        RecipeInstruction(
            id: "step-2", title: "Make the sauce",
            text: "Whisk the egg yolks with the grated pecorino and a generous amount of black pepper.",
            ingredientReferences: nil
        ),
        RecipeInstruction(
            id: "step-3", title: nil,
            text: "Crisp the pancetta in the olive oil, then toss everything together off the heat, loosening the sauce with a splash of pasta water.",
            ingredientReferences: nil
        ),
    ]

    static let nutrition = Nutrition(
        calories: "650",
        fatContent: "24",
        proteinContent: "28",
        carbohydrateContent: "78",
        fiberContent: "4",
        sodiumContent: "890",
        sugarContent: "3"
    )

    static let recipe = Recipe(
        id: "recipe-carbonara",
        slug: "spaghetti-carbonara",
        name: "Spaghetti Carbonara",
        description: "A classic Roman pasta made with egg yolks, pecorino romano, crispy pancetta, and plenty of black pepper. Creamy without any cream, and on the table in about half an hour of active work.",
        image: nil,
        recipeCategory: categories,
        tags: tags,
        tools: nil,
        rating: 4,
        recipeYield: "4 servings",
        recipeIngredient: ingredients,
        recipeInstructions: instructions,
        totalTime: "PT1H30M",
        prepTime: "PT20M",
        performTime: "PT1H10M",
        nutrition: nutrition,
        settings: nil,
        dateAdded: "2025-01-15",
        dateUpdated: "2025-02-01",
        createdAt: "2025-01-15T10:00:00Z",
        updatedAt: "2025-02-01T10:00:00Z",
        orgURL: "https://example.com/recipes/carbonara",
        extras: nil
    )

    // MARK: - Recipe list

    static let recipeSummaries: [RecipeSummary] = [
        RecipeSummary(
            id: "recipe-carbonara", slug: "spaghetti-carbonara",
            name: "Spaghetti Carbonara",
            description: "A classic Roman pasta made with egg yolks, pecorino, and pancetta.",
            image: nil, recipeCategory: [categories[1]], tags: [tags[0]],
            rating: 4, dateAdded: "2025-01-15", dateUpdated: "2025-02-01"
        ),
        RecipeSummary(
            id: "recipe-tikka", slug: "chicken-tikka-masala",
            name: "Chicken Tikka Masala",
            description: "Chargrilled chicken simmered in a spiced tomato and cream sauce.",
            image: nil, recipeCategory: [categories[0]], tags: [tags[1]],
            rating: 5, dateAdded: "2025-01-10", dateUpdated: "2025-01-10"
        ),
        RecipeSummary(
            id: "recipe-kale-caesar", slug: "kale-caesar-salad",
            name: "Kale Caesar Salad",
            description: "Crunchy kale with a garlicky caesar dressing and toasted breadcrumbs.",
            image: nil, recipeCategory: nil, tags: nil,
            rating: nil, dateAdded: "2025-01-05", dateUpdated: "2025-01-05"
        ),
    ]

    static let recipeSummary = recipeSummaries[0]

    // MARK: - Meal plan (fixed week: Mon 2025-03-10 ... Sun 2025-03-16)

    static let weekStart: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 10
        return Calendar.current.startOfDay(for: Calendar.current.date(from: components)!)
    }()

    static func mealPlanEntry(
        id: Int,
        date: String,
        entryType: String,
        title: String = "",
        recipe: RecipeSummary? = nil
    ) -> MealPlanEntry {
        MealPlanEntry(
            id: id, date: date, entryType: entryType,
            title: title, text: "",
            recipeId: recipe?.id, recipe: recipe,
            groupId: nil, householdId: nil
        )
    }

    static let weekEntries: [String: [MealPlanEntry]] = [
        "2025-03-10": [
            mealPlanEntry(id: 1, date: "2025-03-10", entryType: "breakfast", title: "Overnight Oats"),
            mealPlanEntry(id: 2, date: "2025-03-10", entryType: "dinner", recipe: recipeSummaries[0]),
        ],
        "2025-03-12": [
            mealPlanEntry(id: 3, date: "2025-03-12", entryType: "lunch", recipe: recipeSummaries[1]),
        ],
        "2025-03-15": [
            mealPlanEntry(id: 4, date: "2025-03-15", entryType: "dinner", title: "Pizza Night"),
            mealPlanEntry(id: 5, date: "2025-03-15", entryType: "side", title: "Fruit Salad"),
        ],
    ]

    // MARK: - Shopping list

    static let shoppingListId = "snapshot-shopping-list"

    static func shoppingItem(
        id: String,
        note: String? = nil,
        quantity: Double? = nil,
        unit: String? = nil,
        food: String? = nil,
        checked: Bool,
        position: Int
    ) -> ShoppingListItem {
        ShoppingListItem(
            id: id,
            shoppingListId: shoppingListId,
            checked: checked,
            position: position,
            isFood: food != nil,
            note: note,
            quantity: quantity,
            unit: unit.map { IngredientUnit(id: "unit-\($0)", name: $0, abbreviation: nil, description: nil) },
            food: food.map { IngredientFood(id: "food-\($0)", name: $0, description: nil, labelId: nil) },
            labelId: nil,
            extras: nil
        )
    }

    static let shoppingList = ShoppingList(
        id: shoppingListId,
        name: "Groceries",
        groupId: nil,
        householdId: nil,
        listItems: [
            shoppingItem(id: "item-1", quantity: 2, unit: "lb", food: "chicken thighs", checked: false, position: 0),
            shoppingItem(id: "item-2", note: "the crusty kind", quantity: 1, food: "sourdough bread", checked: false, position: 1),
            shoppingItem(id: "item-3", note: "paper towels", checked: false, position: 2),
            shoppingItem(id: "item-4", quantity: 12, food: "eggs", checked: true, position: 3),
            shoppingItem(id: "item-5", quantity: 1, unit: "gallon", food: "milk", checked: true, position: 4),
        ],
        createdAt: nil,
        updatedAt: nil
    )

    // MARK: - Auth / user

    static let savedServer = SavedServer(url: "https://mealie.example.com", email: "demo@example.com")

    static let user = User(
        id: "user-1",
        username: "demo",
        fullName: "Demo User",
        email: "demo@example.com",
        admin: false,
        group: "Home",
        household: "Home",
        groupId: nil,
        householdId: nil,
        tokens: nil,
        canInvite: nil,
        canManage: nil,
        canOrganize: nil,
        favoriteRecipes: nil
    )
}
