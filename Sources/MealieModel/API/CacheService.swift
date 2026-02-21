import Foundation
import SkipFuse

public class CacheService: @unchecked Sendable {
    public static let shared = CacheService()

    private let cacheDirectoryName = "mealie_cache"

    private init() {}

    // MARK: - Recipe List

    public func saveRecipeList(_ recipes: [RecipeSummary]) {
        save(recipes, filename: "recipe_list.json")
    }

    public func loadRecipeList() -> [RecipeSummary]? {
        load(filename: "recipe_list.json")
    }

    // MARK: - Recipe Detail

    public func saveRecipeDetail(_ recipe: Recipe, slug: String) {
        save(recipe, filename: "recipe_detail_\(slug).json")
    }

    public func loadRecipeDetail(slug: String) -> Recipe? {
        load(filename: "recipe_detail_\(slug).json")
    }

    // MARK: - Shopping Lists

    public func saveShoppingLists(_ lists: [ShoppingList]) {
        save(lists, filename: "shopping_lists.json")
    }

    public func loadShoppingLists() -> [ShoppingList]? {
        load(filename: "shopping_lists.json")
    }

    // MARK: - Shopping List Detail

    public func saveShoppingListDetail(_ list: ShoppingList, id: String) {
        save(list, filename: "shopping_list_\(id).json")
    }

    public func loadShoppingListDetail(id: String) -> ShoppingList? {
        load(filename: "shopping_list_\(id).json")
    }

    // MARK: - Meal Plan Week

    public func saveMealPlanWeek(_ entries: [MealPlanEntry], startDate: String) {
        save(entries, filename: "mealplan_\(startDate).json")
    }

    public func loadMealPlanWeek(startDate: String) -> [MealPlanEntry]? {
        load(filename: "mealplan_\(startDate).json")
    }

    // MARK: - Categories & Tags

    public func saveCategories(_ categories: [RecipeCategory]) {
        save(categories, filename: "categories.json")
    }

    public func loadCategories() -> [RecipeCategory]? {
        load(filename: "categories.json")
    }

    public func saveTags(_ tags: [RecipeTag]) {
        save(tags, filename: "tags.json")
    }

    public func loadTags() -> [RecipeTag]? {
        load(filename: "tags.json")
    }

    // MARK: - Clear

    public func clearAll() {
        guard let dir = cacheDirectory() else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Private Helpers

    private func cacheDirectory() -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return caches.appendingPathComponent(cacheDirectoryName)
    }

    private func save<T: Encodable>(_ value: T, filename: String) {
        guard let dir = cacheDirectory() else { return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(value)
            let fileURL = dir.appendingPathComponent(filename)
            try data.write(to: fileURL)
        } catch {
            print("Cache save error (\(filename)): \(error)")
        }
    }

    private func load<T: Decodable>(filename: String) -> T? {
        guard let dir = cacheDirectory() else { return nil }
        let fileURL = dir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
