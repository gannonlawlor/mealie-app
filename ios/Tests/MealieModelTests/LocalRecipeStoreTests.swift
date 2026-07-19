import XCTest
import Foundation
@testable import MealieModel

/// Tests the FileRecipeStore (file-based persistence).
/// SwiftData store requires an app container and is tested separately.
final class LocalRecipeStoreTests: XCTestCase {
    var store: FileRecipeStore!

    override func setUp() {
        super.setUp()
        store = FileRecipeStore()
        // Clean slate for each test
        for recipe in store.loadAllRecipes() {
            if let id = recipe.id {
                store.deleteRecipe(id: id)
            }
        }
        store.saveFavorites([])
    }

    override func tearDown() {
        // Clean up after tests
        for recipe in store.loadAllRecipes() {
            if let id = recipe.id {
                store.deleteRecipe(id: id)
            }
        }
        store.saveFavorites([])
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

    // MARK: - Slug Generation (tested via LocalRecipeStore facade)

    func testGenerateSlugBasic() {
        XCTAssertEqual(LocalRecipeStore.shared.generateSlug(from: "Chicken Alfredo"), "chicken-alfredo")
    }

    func testGenerateSlugStripsSpecialCharacters() {
        XCTAssertEqual(LocalRecipeStore.shared.generateSlug(from: "Mom's Best Pie!"), "moms-best-pie")
    }

    func testGenerateSlugHandlesNumbers() {
        XCTAssertEqual(LocalRecipeStore.shared.generateSlug(from: "5 Minute Pasta"), "5-minute-pasta")
    }

    func testGenerateSlugEmptyStringFallback() {
        XCTAssertEqual(LocalRecipeStore.shared.generateSlug(from: ""), "recipe")
        XCTAssertEqual(LocalRecipeStore.shared.generateSlug(from: "!!!"), "recipe")
    }

    // MARK: - Image Storage (tested via LocalRecipeStore facade)

    func testSaveAndLoadImage() {
        let recipeId = "img-test-id"
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header bytes

        let path = LocalRecipeStore.shared.saveImage(data: imageData, recipeId: recipeId)
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(path.contains(recipeId))

        let loadedPath = LocalRecipeStore.shared.imageFilePath(recipeId: recipeId)
        XCTAssertNotNil(loadedPath)
        XCTAssertEqual(path, loadedPath)

        // Verify file contents
        let loadedData = try? Data(contentsOf: URL(fileURLWithPath: path))
        XCTAssertEqual(loadedData, imageData)

        // Cleanup
        LocalRecipeStore.shared.deleteImage(recipeId: recipeId)
    }

    func testImageFilePathReturnsNilWhenNoImage() {
        XCTAssertNil(LocalRecipeStore.shared.imageFilePath(recipeId: "nonexistent-image"))
    }

    func testDeleteImageRemovesFile() {
        let recipeId = "del-img-test"
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let path = LocalRecipeStore.shared.saveImage(data: imageData, recipeId: recipeId)
        XCTAssertFalse(path.isEmpty)

        LocalRecipeStore.shared.deleteImage(recipeId: recipeId)
        XCTAssertNil(LocalRecipeStore.shared.imageFilePath(recipeId: recipeId))
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
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

    // MARK: - Favorites (file-based)

    func testAddAndLoadFavorite() {
        store.addFavorite(slug: "pasta")
        store.addFavorite(slug: "cake")

        let favorites = store.loadFavorites()
        XCTAssertTrue(favorites.contains("pasta"))
        XCTAssertTrue(favorites.contains("cake"))
        XCTAssertEqual(favorites.count, 2)
    }

    func testRemoveFavorite() {
        store.addFavorite(slug: "pasta")
        store.addFavorite(slug: "cake")
        store.removeFavorite(slug: "pasta")

        let favorites = store.loadFavorites()
        XCTAssertFalse(favorites.contains("pasta"))
        XCTAssertTrue(favorites.contains("cake"))
        XCTAssertEqual(favorites.count, 1)
    }

    func testFavoritesStartEmpty() {
        XCTAssertTrue(store.loadFavorites().isEmpty)
    }

    func testAddDuplicateFavoriteIsNoOp() {
        store.addFavorite(slug: "pasta")
        store.addFavorite(slug: "pasta")

        XCTAssertEqual(store.loadFavorites().count, 1)
    }

    func testRemoveNonexistentFavoriteIsNoOp() {
        store.addFavorite(slug: "pasta")
        store.removeFavorite(slug: "nonexistent")

        XCTAssertEqual(store.loadFavorites().count, 1)
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

    // MARK: - Per-Recipe File Storage

    func testEachRecipeIsStoredInSeparateFile() {
        store.saveRecipe(makeRecipe(id: "r1", slug: "one", name: "One"))
        store.saveRecipe(makeRecipe(id: "r2", slug: "two", name: "Two"))

        // Verify files exist individually
        guard let dir = store.storeDirectory() else {
            XCTFail("Store directory should exist")
            return
        }
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("recipe_r1.json").path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("recipe_r2.json").path))

        // Delete one, other should remain
        store.deleteRecipe(id: "r1")
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("recipe_r1.json").path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("recipe_r2.json").path))
        XCTAssertEqual(store.recipeCount(), 1)
    }

    // MARK: - Migration

    func testMigrationFromSingleFileFormat() {
        // Manually create a legacy recipes.json
        guard let dir = store.storeDirectory() else {
            XCTFail("Store directory should exist")
            return
        }
        let legacyFile = dir.appendingPathComponent("recipes.json")
        let recipes = [
            makeRecipe(id: "m1", slug: "migrated-one", name: "Migrated One"),
            makeRecipe(id: "m2", slug: "migrated-two", name: "Migrated Two")
        ]
        let data = try! JSONEncoder().encode(recipes)
        try! data.write(to: legacyFile)

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: legacyFile.path))

        // Simulate migration by reading and saving per-recipe
        for recipe in recipes {
            store.saveRecipe(recipe)
        }
        try? fm.removeItem(at: legacyFile)

        // Verify per-recipe files exist and legacy file is gone
        XCTAssertFalse(fm.fileExists(atPath: legacyFile.path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("recipe_m1.json").path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("recipe_m2.json").path))

        let loaded = store.loadAllRecipes()
        XCTAssertEqual(loaded.count, 2)
        let names = Set(loaded.compactMap { $0.name })
        XCTAssertTrue(names.contains("Migrated One"))
        XCTAssertTrue(names.contains("Migrated Two"))
    }

    // MARK: - Search

    func testFindRecipeByOrgURL() {
        let recipe = Recipe(
            id: "url-test", slug: "url-recipe", name: "URL Recipe",
            description: nil, image: nil, recipeCategory: nil, tags: nil,
            tools: nil, rating: nil, recipeYield: nil,
            recipeIngredient: nil, recipeInstructions: nil,
            totalTime: nil, prepTime: nil, performTime: nil,
            nutrition: nil, settings: nil,
            dateAdded: nil, dateUpdated: nil, createdAt: nil, updatedAt: nil,
            orgURL: "https://example.com/my-recipe", extras: nil
        )
        store.saveRecipe(recipe)

        XCTAssertNotNil(store.findRecipeByOrgURL("https://example.com/my-recipe"))
        XCTAssertNil(store.findRecipeByOrgURL("https://example.com/other"))
    }

    func testFindRecipesByName() {
        store.saveRecipe(makeRecipe(id: "r1", slug: "pasta", name: "Pasta"))
        store.saveRecipe(makeRecipe(id: "r2", slug: "pasta-2", name: "Pasta"))
        store.saveRecipe(makeRecipe(id: "r3", slug: "cake", name: "Cake"))

        let results = store.findRecipesByName("Pasta")
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - RecipePersistence protocol conformance

    func testFileStoreConformsToProtocol() {
        let persistence: RecipePersistence = store
        persistence.saveRecipe(makeRecipe())
        XCTAssertEqual(persistence.recipeCount(), 1)
        XCTAssertNotNil(persistence.loadRecipe(slug: "test-recipe"))
    }
}
