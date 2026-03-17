#if os(Android)
import Foundation
import SkipFuse

private let logger = Log(category: "AndroidSQLiteStore")

public class AndroidSQLiteRecipeStore: RecipePersistence, @unchecked Sendable {
    private let db: AnyDynamicObject

    public init() {
        let context = ProcessInfo.processInfo.androidContext
        db = try! AnyDynamicObject(className: "mealie.app.db.RecipeDatabase", context)
    }

    // MARK: - Recipes

    public func loadAllRecipes() -> [Recipe] {
        guard let jsonList: [String] = try? db.loadAllRecipes() else { return [] }
        return jsonList.compactMap { json in
            do {
                return try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            } catch {
                logger.error("Failed to decode recipe JSON: \(error)")
                return nil
            }
        }
    }

    public func loadRecipe(slug: String) -> Recipe? {
        guard let json: String = try? db.loadRecipe(slug) else { return nil }
        return try? JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
    }

    public func saveRecipe(_ recipe: Recipe) {
        guard let id = recipe.id else { return }
        guard let data = try? JSONEncoder().encode(recipe),
              let json = String(data: data, encoding: .utf8) else {
            logger.error("Failed to encode recipe \(id)")
            return
        }
        do {
            try db.saveRecipe(id, recipe.slug as Any, recipe.name as Any, json, recipe.dateUpdated as Any)
        } catch {
            logger.error("Failed to save recipe \(id): \(error)")
        }
    }

    public func deleteRecipe(id: String) {
        do {
            try db.deleteRecipe(id)
        } catch {
            logger.error("Failed to delete recipe \(id): \(error)")
        }
    }

    public func recipeSummaries() -> [RecipeSummary] {
        loadAllRecipes().map { recipe in
            RecipeSummary(
                id: recipe.id,
                slug: recipe.slug,
                name: recipe.name,
                description: recipe.description,
                image: recipe.image,
                recipeCategory: recipe.recipeCategory,
                tags: recipe.tags,
                rating: recipe.rating,
                dateAdded: recipe.dateAdded,
                dateUpdated: recipe.dateUpdated
            )
        }
    }

    public func recipeCount() -> Int {
        (try? db.recipeCount() as Int?) ?? 0
    }

    // MARK: - Search

    public func findRecipeByOrgURL(_ url: String) -> Recipe? {
        loadAllRecipes().first { $0.orgURL == url }
    }

    public func findRecipesByName(_ name: String) -> [Recipe] {
        let query = name.lowercased()
        return loadAllRecipes().filter { ($0.name ?? "").lowercased() == query }
    }

    // MARK: - Favorites

    public func loadFavorites() -> Set<String> {
        guard let slugs: [String] = try? db.loadFavorites() else { return [] }
        return Set(slugs)
    }

    public func saveFavorites(_ favorites: Set<String>) {
        do {
            try db.saveFavorites(Array(favorites))
        } catch {
            logger.error("Failed to save favorites: \(error)")
        }
    }

    public func addFavorite(slug: String) {
        do {
            try db.addFavorite(slug)
        } catch {
            logger.error("Failed to add favorite \(slug): \(error)")
        }
    }

    public func removeFavorite(slug: String) {
        do {
            try db.removeFavorite(slug)
        } catch {
            logger.error("Failed to remove favorite \(slug): \(error)")
        }
    }
}
#endif
