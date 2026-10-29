import Foundation

public protocol RecipePersistence: AnyObject, Sendable {
    // Recipes
    func loadAllRecipes() -> [Recipe]
    func loadRecipe(slug: String) -> Recipe?
    func saveRecipe(_ recipe: Recipe) throws
    func deleteRecipe(id: String) throws
    func recipeSummaries() -> [RecipeSummary]
    func recipeCount() -> Int

    // Search
    func findRecipeByOrgURL(_ url: String) -> Recipe?
    func findRecipesByName(_ name: String) -> [Recipe]

    // Favorites
    func loadFavorites() -> Set<String>
    func saveFavorites(_ favorites: Set<String>) throws
    func addFavorite(slug: String) throws
    func removeFavorite(slug: String) throws
}

public enum RecipeStorageError: LocalizedError {
    case unavailable
    case missingRecipeID

    public var errorDescription: String? {
        switch self {
        case .unavailable: return "Your recipe library could not be opened. Your saved data has been preserved. Try again or restart the app."
        case .missingRecipeID: return "This recipe has no identifier and could not be saved."
        }
    }
}
