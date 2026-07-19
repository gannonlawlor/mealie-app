import Foundation

public protocol RecipePersistence: AnyObject, Sendable {
    // Recipes
    func loadAllRecipes() -> [Recipe]
    func loadRecipe(slug: String) -> Recipe?
    func saveRecipe(_ recipe: Recipe)
    func deleteRecipe(id: String)
    func recipeSummaries() -> [RecipeSummary]
    func recipeCount() -> Int

    // Search
    func findRecipeByOrgURL(_ url: String) -> Recipe?
    func findRecipesByName(_ name: String) -> [Recipe]

    // Favorites
    func loadFavorites() -> Set<String>
    func saveFavorites(_ favorites: Set<String>)
    func addFavorite(slug: String)
    func removeFavorite(slug: String)
}
