import XCTest
import Foundation
@testable import MealieModel

final class LocalRecipeStoreTests: XCTestCase {
    let store = LocalRecipeStore.shared

    override func setUp() {
        super.setUp()
        // Clean slate for each test
        for recipe in store.loadAllRecipes() {
            if let id = recipe.id {
                store.deleteRecipe(id: id)
            }
        }
    }

    override func tearDown() {
        // Clean up after tests
        for recipe in store.loadAllRecipes() {
            if let id = recipe.id {
                store.deleteRecipe(id: id)
            }
        }
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeRecipe(id: String = "test-id", slug: String = "test-recipe", name: String = "Test Recipe") -> Recipe {
        Recipe(
            id: id, slug: slug, name: name, description: "A test recipe",
            image: nil, recipeCategory: nil, tags: nil, tools: nil,
            rating: 4, recipeYield: "4 servings",
            recipeIngredient: [
                RecipeIngredient(quantity: 2.0, unit: nil, food: nil, note: "cups flour",
                                 isFood: true, disableAmount: false, display: "2 cups flour",
                                 title: nil, originalText: "2 cups flour", referenceId: nil)
            ],
            recipeInstructions: [
                RecipeInstruction(id: "s1", title: nil, text: "Mix ingredients", ingredientReferences: nil)
            ],
            totalTime: "PT30M", prepTime: "PT10M", performTime: "PT20M",
            nutrition: nil, settings: nil,
            dateAdded: "2025-01-01", dateUpdated: "2025-01-02",
            createdAt: "2025-01-01T00:00:00", updatedAt: "2025-01-02T00:00:00",
            orgURL: nil, extras: nil
        )
    }

    // MARK: - Save and Load

    func testSaveAndLoadRecipe() {
        let recipe = makeRecipe()
        store.saveRecipe(recipe)

        let loaded = store.loadAllRecipes()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, "test-id")
        XCTAssertEqual(loaded[0].name, "Test Recipe")
        XCTAssertEqual(loaded[0].slug, "test-recipe")
    }

    func testLoadRecipeBySlug() {
        store.saveRecipe(makeRecipe())

        let found = store.loadRecipe(slug: "test-recipe")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Test Recipe")

        let notFound = store.loadRecipe(slug: "nonexistent")
        XCTAssertNil(notFound)
    }

    func testSaveMultipleRecipes() {
        store.saveRecipe(makeRecipe(id: "r1", slug: "recipe-one", name: "Recipe One"))
        store.saveRecipe(makeRecipe(id: "r2", slug: "recipe-two", name: "Recipe Two"))
        store.saveRecipe(makeRecipe(id: "r3", slug: "recipe-three", name: "Recipe Three"))

        let all = store.loadAllRecipes()
        XCTAssertEqual(all.count, 3)

        let names = Set(all.compactMap { $0.name })
        XCTAssertTrue(names.contains("Recipe One"))
        XCTAssertTrue(names.contains("Recipe Two"))
        XCTAssertTrue(names.contains("Recipe Three"))
    }

    // MARK: - Update (upsert)

    func testSaveRecipeUpdatesExistingById() {
        store.saveRecipe(makeRecipe(id: "r1", slug: "old-slug", name: "Old Name"))
        XCTAssertEqual(store.loadAllRecipes().count, 1)

        // Save with same id but different name
        store.saveRecipe(makeRecipe(id: "r1", slug: "new-slug", name: "New Name"))

        let all = store.loadAllRecipes()
        XCTAssertEqual(all.count, 1, "Should update, not append")
        XCTAssertEqual(all[0].name, "New Name")
        XCTAssertEqual(all[0].slug, "new-slug")
    }

    // MARK: - Delete

    func testDeleteRecipe() {
        store.saveRecipe(makeRecipe(id: "r1", slug: "recipe-one", name: "Recipe One"))
        store.saveRecipe(makeRecipe(id: "r2", slug: "recipe-two", name: "Recipe Two"))
        XCTAssertEqual(store.loadAllRecipes().count, 2)

        store.deleteRecipe(id: "r1")

        let remaining = store.loadAllRecipes()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].id, "r2")
    }

    func testDeleteNonexistentRecipeIsNoOp() {
        store.saveRecipe(makeRecipe())
        store.deleteRecipe(id: "nonexistent")
        XCTAssertEqual(store.loadAllRecipes().count, 1)
    }

    // MARK: - Recipe Count

    func testRecipeCount() {
        XCTAssertEqual(store.recipeCount(), 0)

        store.saveRecipe(makeRecipe(id: "r1", slug: "a", name: "A"))
        XCTAssertEqual(store.recipeCount(), 1)

        store.saveRecipe(makeRecipe(id: "r2", slug: "b", name: "B"))
        XCTAssertEqual(store.recipeCount(), 2)

        store.deleteRecipe(id: "r1")
        XCTAssertEqual(store.recipeCount(), 1)
    }

    // MARK: - Recipe Summaries

    func testRecipeSummariesMapsFieldsCorrectly() {
        let recipe = Recipe(
            id: "sum-id", slug: "summary-test", name: "Summary Test",
            description: "Summary desc", image: "img.jpg",
            recipeCategory: [RecipeCategory(id: "c1", name: "Dinner", slug: "dinner")],
            tags: [RecipeTag(id: "t1", name: "Easy", slug: "easy")],
            tools: nil, rating: 5, recipeYield: "2",
            recipeIngredient: nil, recipeInstructions: nil,
            totalTime: nil, prepTime: nil, performTime: nil,
            nutrition: nil, settings: nil,
            dateAdded: "2025-06-01", dateUpdated: "2025-06-02",
            createdAt: nil, updatedAt: nil, orgURL: nil, extras: nil
        )
        store.saveRecipe(recipe)

        let summaries = store.recipeSummaries()
        XCTAssertEqual(summaries.count, 1)

        let s = summaries[0]
        XCTAssertEqual(s.id, "sum-id")
        XCTAssertEqual(s.slug, "summary-test")
        XCTAssertEqual(s.name, "Summary Test")
        XCTAssertEqual(s.description, "Summary desc")
        XCTAssertEqual(s.image, "img.jpg")
        XCTAssertEqual(s.recipeCategory?.count, 1)
        XCTAssertEqual(s.recipeCategory?.first?.name, "Dinner")
        XCTAssertEqual(s.tags?.count, 1)
        XCTAssertEqual(s.tags?.first?.name, "Easy")
        XCTAssertEqual(s.rating, 5)
        XCTAssertEqual(s.dateAdded, "2025-06-01")
        XCTAssertEqual(s.dateUpdated, "2025-06-02")
    }

    // MARK: - Slug Generation

    func testGenerateSlugBasic() {
        XCTAssertEqual(store.generateSlug(from: "Chicken Alfredo"), "chicken-alfredo")
    }

    func testGenerateSlugStripsSpecialCharacters() {
        XCTAssertEqual(store.generateSlug(from: "Mom's Best Pie!"), "moms-best-pie")
    }

    func testGenerateSlugHandlesNumbers() {
        XCTAssertEqual(store.generateSlug(from: "5 Minute Pasta"), "5-minute-pasta")
    }

    func testGenerateSlugEmptyStringFallback() {
        XCTAssertEqual(store.generateSlug(from: ""), "recipe")
        XCTAssertEqual(store.generateSlug(from: "!!!"), "recipe")
    }

    // MARK: - Image Storage

    func testSaveAndLoadImage() {
        let recipeId = "img-test-id"
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header bytes

        let path = store.saveImage(data: imageData, recipeId: recipeId)
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(path.contains(recipeId))

        let loadedPath = store.imageFilePath(recipeId: recipeId)
        XCTAssertNotNil(loadedPath)
        XCTAssertEqual(path, loadedPath)

        // Verify file contents
        let loadedData = try? Data(contentsOf: URL(fileURLWithPath: path))
        XCTAssertEqual(loadedData, imageData)

        // Cleanup
        store.deleteImage(recipeId: recipeId)
    }

    func testImageFilePathReturnsNilWhenNoImage() {
        XCTAssertNil(store.imageFilePath(recipeId: "nonexistent-image"))
    }

    func testDeleteImageRemovesFile() {
        let recipeId = "del-img-test"
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let path = store.saveImage(data: imageData, recipeId: recipeId)
        XCTAssertFalse(path.isEmpty)

        store.deleteImage(recipeId: recipeId)
        XCTAssertNil(store.imageFilePath(recipeId: recipeId))
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testDeleteRecipeAlsoDeletesImage() {
        let recipeId = "recipe-with-img"
        store.saveRecipe(makeRecipe(id: recipeId, slug: "with-img", name: "With Image"))
        _ = store.saveImage(data: Data([0x01, 0x02]), recipeId: recipeId)
        XCTAssertNotNil(store.imageFilePath(recipeId: recipeId))

        store.deleteRecipe(id: recipeId)

        XCTAssertNil(store.imageFilePath(recipeId: recipeId))
        XCTAssertNil(store.loadRecipe(slug: "with-img"))
    }

    // MARK: - Persistence (encode/decode round-trip)

    func testRecipeFieldsSurviveRoundTrip() {
        let recipe = Recipe(
            id: "rt-id", slug: "round-trip", name: "Round Trip",
            description: "Full fields test", image: nil,
            recipeCategory: [RecipeCategory(id: "c1", name: "Italian", slug: "italian")],
            tags: [RecipeTag(id: "t1", name: "Quick", slug: "quick")],
            tools: [RecipeTool(id: "tool1", name: "Oven", slug: "oven", onHand: true)],
            rating: 3, recipeYield: "6 servings",
            recipeIngredient: [
                RecipeIngredient(quantity: 1.5, unit: IngredientUnit(id: "u1", name: "cup", abbreviation: "c", description: nil),
                                 food: IngredientFood(id: "f1", name: "flour", description: nil, labelId: nil),
                                 note: "sifted", isFood: true, disableAmount: false,
                                 display: "1.5 cups flour, sifted", title: nil,
                                 originalText: "1 1/2 cups flour, sifted", referenceId: "ref1")
            ],
            recipeInstructions: [
                RecipeInstruction(id: "i1", title: "Prep", text: "Sift the flour", ingredientReferences: ["ref1"]),
                RecipeInstruction(id: "i2", title: nil, text: "Bake at 350F", ingredientReferences: nil)
            ],
            totalTime: "PT1H", prepTime: "PT20M", performTime: "PT40M",
            nutrition: Nutrition(calories: "350", fatContent: "12g", proteinContent: "8g",
                                  carbohydrateContent: "45g", fiberContent: "3g",
                                  sodiumContent: "200mg", sugarContent: "5g"),
            settings: nil,
            dateAdded: "2025-03-01", dateUpdated: "2025-03-15",
            createdAt: "2025-03-01T10:00:00", updatedAt: "2025-03-15T14:30:00",
            orgURL: "https://example.com/recipe", extras: ["source": "web"]
        )

        store.saveRecipe(recipe)
        let loaded = store.loadRecipe(slug: "round-trip")

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, "rt-id")
        XCTAssertEqual(loaded?.name, "Round Trip")
        XCTAssertEqual(loaded?.description, "Full fields test")
        XCTAssertEqual(loaded?.rating, 3)
        XCTAssertEqual(loaded?.recipeYield, "6 servings")
        XCTAssertEqual(loaded?.totalTime, "PT1H")
        XCTAssertEqual(loaded?.prepTime, "PT20M")
        XCTAssertEqual(loaded?.performTime, "PT40M")
        XCTAssertEqual(loaded?.orgURL, "https://example.com/recipe")
        XCTAssertEqual(loaded?.extras?["source"], "web")

        // Categories & tags
        XCTAssertEqual(loaded?.recipeCategory?.count, 1)
        XCTAssertEqual(loaded?.recipeCategory?.first?.name, "Italian")
        XCTAssertEqual(loaded?.tags?.count, 1)
        XCTAssertEqual(loaded?.tags?.first?.name, "Quick")

        // Tools
        XCTAssertEqual(loaded?.tools?.count, 1)
        XCTAssertEqual(loaded?.tools?.first?.name, "Oven")
        XCTAssertEqual(loaded?.tools?.first?.onHand, true)

        // Ingredients
        XCTAssertEqual(loaded?.recipeIngredient?.count, 1)
        let ing = loaded?.recipeIngredient?.first
        XCTAssertEqual(ing?.quantity, 1.5)
        XCTAssertEqual(ing?.unit?.name, "cup")
        XCTAssertEqual(ing?.food?.name, "flour")
        XCTAssertEqual(ing?.note, "sifted")
        XCTAssertEqual(ing?.display, "1.5 cups flour, sifted")

        // Instructions
        XCTAssertEqual(loaded?.recipeInstructions?.count, 2)
        XCTAssertEqual(loaded?.recipeInstructions?[0].title, "Prep")
        XCTAssertEqual(loaded?.recipeInstructions?[0].text, "Sift the flour")
        XCTAssertEqual(loaded?.recipeInstructions?[1].text, "Bake at 350F")

        // Nutrition
        XCTAssertEqual(loaded?.nutrition?.calories, "350")
        XCTAssertEqual(loaded?.nutrition?.proteinContent, "8g")

        // Dates
        XCTAssertEqual(loaded?.dateAdded, "2025-03-01")
        XCTAssertEqual(loaded?.createdAt, "2025-03-01T10:00:00")
    }

    // MARK: - Empty Store

    func testEmptyStoreReturnsEmptyArrays() {
        XCTAssertTrue(store.loadAllRecipes().isEmpty)
        XCTAssertTrue(store.recipeSummaries().isEmpty)
        XCTAssertEqual(store.recipeCount(), 0)
    }

    func testLoadRecipeFromEmptyStoreReturnsNil() {
        XCTAssertNil(store.loadRecipe(slug: "anything"))
    }
}
