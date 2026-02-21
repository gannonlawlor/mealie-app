import XCTest
import Foundation
@testable import MealieModel

final class ModelDecodingTests: XCTestCase {

    // MARK: - AuthToken

    func testAuthTokenDecodesSnakeCaseKeys() throws {
        let json = """
        {"access_token": "abc123", "token_type": "bearer"}
        """.data(using: .utf8)!

        let token = try JSONDecoder().decode(AuthToken.self, from: json)
        XCTAssertEqual(token.accessToken, "abc123")
        XCTAssertEqual(token.tokenType, "bearer")
    }

    // MARK: - RecipeSettings

    func testRecipeSettingsDecodesPublicKey() throws {
        let json = """
        {"public": true, "showNutrition": false, "showAssets": true, "landscapeView": false, "disableComments": false, "disableAmount": false}
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(RecipeSettings.self, from: json)
        XCTAssertEqual(settings.isPublic, true)
        XCTAssertEqual(settings.showNutrition, false)
    }

    // MARK: - RecipePaginatedResponse

    func testRecipePaginatedResponseDecodesSnakeCaseKeys() throws {
        let json = """
        {"page": 1, "per_page": 10, "total": 25, "total_pages": 3, "items": []}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RecipePaginatedResponse.self, from: json)
        XCTAssertEqual(response.page, 1)
        XCTAssertEqual(response.perPage, 10)
        XCTAssertEqual(response.total, 25)
        XCTAssertEqual(response.totalPages, 3)
        XCTAssertTrue(response.items.isEmpty)
    }

    // MARK: - MealPlanEntry

    func testMealPlanEntryIdIsInt() throws {
        let json = """
        {"id": 42, "date": "2025-01-15", "entryType": "dinner", "title": "Test"}
        """.data(using: .utf8)!

        let entry = try JSONDecoder().decode(MealPlanEntry.self, from: json)
        XCTAssertEqual(entry.id, 42)
    }

    // MARK: - Recipe round-trip

    func testRecipeEncodeDecodeRoundTrip() throws {
        let recipe = Recipe(
            id: "abc-123", slug: "test-recipe", name: "Test Recipe",
            description: "A test", image: nil,
            recipeCategory: [RecipeCategory(id: "c1", name: "Cat", slug: "cat")],
            tags: nil, tools: nil, rating: 4, recipeYield: "4 servings",
            recipeIngredient: [
                RecipeIngredient(quantity: 2.0, unit: nil, food: nil, note: "chopped",
                                 isFood: true, disableAmount: false, display: "2 chopped",
                                 title: nil, originalText: nil, referenceId: nil)
            ],
            recipeInstructions: [
                RecipeInstruction(id: "s1", title: nil, text: "Step 1", ingredientReferences: nil)
            ],
            totalTime: "30 min", prepTime: "10 min", performTime: "20 min",
            nutrition: Nutrition(calories: "200", fatContent: "10", proteinContent: "15",
                                 carbohydrateContent: "20", fiberContent: "5",
                                 sodiumContent: "100", sugarContent: "3"),
            settings: nil, dateAdded: "2025-01-01", dateUpdated: "2025-01-02",
            createdAt: "2025-01-01T00:00:00", updatedAt: "2025-01-02T00:00:00",
            orgURL: "https://example.com", extras: ["key": "value"]
        )

        let data = try JSONEncoder().encode(recipe)
        let decoded = try JSONDecoder().decode(Recipe.self, from: data)

        XCTAssertEqual(decoded.id, "abc-123")
        XCTAssertEqual(decoded.slug, "test-recipe")
        XCTAssertEqual(decoded.name, "Test Recipe")
        XCTAssertEqual(decoded.rating, 4)
        XCTAssertEqual(decoded.recipeYield, "4 servings")
        XCTAssertEqual(decoded.recipeIngredient?.count, 1)
        XCTAssertEqual(decoded.recipeInstructions?.count, 1)
        XCTAssertEqual(decoded.nutrition?.calories, "200")
        XCTAssertEqual(decoded.recipeCategory?.first?.name, "Cat")
        XCTAssertEqual(decoded.orgURL, "https://example.com")
        XCTAssertEqual(decoded.extras?["key"], "value")
    }

    // MARK: - ShoppingList with nested items

    func testShoppingListDecodesWithNestedItems() throws {
        let json = """
        {
            "id": "list-1",
            "name": "Groceries",
            "listItems": [
                {"id": "item-1", "checked": false, "note": "Milk"},
                {"id": "item-2", "checked": true, "note": "Bread"}
            ]
        }
        """.data(using: .utf8)!

        let list = try JSONDecoder().decode(ShoppingList.self, from: json)
        XCTAssertEqual(list.id, "list-1")
        XCTAssertEqual(list.name, "Groceries")
        XCTAssertEqual(list.listItems?.count, 2)
        XCTAssertEqual(list.listItems?[0].note, "Milk")
        XCTAssertEqual(list.listItems?[1].checked, true)
    }

    // MARK: - AppInfo optional fields

    func testAppInfoDecodesWithOptionalFieldsAbsent() throws {
        let json = """
        {"version": "1.5.0"}
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(AppInfo.self, from: json)
        XCTAssertEqual(info.version, "1.5.0")
        XCTAssertNil(info.demoStatus)
        XCTAssertNil(info.allowSignup)
        XCTAssertNil(info.enableOidc)
    }

    func testAppInfoDecodesWithAllFields() throws {
        let json = """
        {"version": "1.5.0", "demoStatus": true, "allowSignup": false, "enableOidc": true}
        """.data(using: .utf8)!

        let info = try JSONDecoder().decode(AppInfo.self, from: json)
        XCTAssertEqual(info.version, "1.5.0")
        XCTAssertEqual(info.demoStatus, true)
        XCTAssertEqual(info.allowSignup, false)
        XCTAssertEqual(info.enableOidc, true)
    }

    // MARK: - MealPlanPaginatedResponse

    func testMealPlanPaginatedResponseDecodes() throws {
        let json = """
        {"page": 2, "per_page": 5, "total": 12, "total_pages": 3, "items": [{"id": 1, "entryType": "lunch"}]}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(MealPlanPaginatedResponse.self, from: json)
        XCTAssertEqual(response.page, 2)
        XCTAssertEqual(response.perPage, 5)
        XCTAssertEqual(response.items.count, 1)
        XCTAssertEqual(response.items[0].id, 1)
    }
}
