import Foundation
import SkipFuse

private let logger = Log(category: "LocalStore")

public class LocalRecipeStore: @unchecked Sendable {
    public static let shared = LocalRecipeStore()

    private let directoryName = "mealie_local"
    private let recipesFilename = "recipes.json"
    private let imagesDirectory = "images"

    private init() {}

    // MARK: - Recipes

    public func loadAllRecipes() -> [Recipe] {
        guard let dir = storeDirectory() else { return [] }
        let fileURL = dir.appendingPathComponent(recipesFilename)
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            return try JSONDecoder().decode([Recipe].self, from: data)
        } catch {
            logger.error("Failed to decode local recipes: \(error)")
            return []
        }
    }

    public func loadRecipe(slug: String) -> Recipe? {
        loadAllRecipes().first { $0.slug == slug }
    }

    public func saveRecipe(_ recipe: Recipe) {
        var recipes = loadAllRecipes()
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipe
        } else {
            recipes.append(recipe)
        }
        saveAllRecipes(recipes)
    }

    public func deleteRecipe(id: String) {
        var recipes = loadAllRecipes()
        recipes.removeAll { $0.id == id }
        saveAllRecipes(recipes)
        deleteImage(recipeId: id)
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

    // MARK: - Images

    public func saveImage(data: Data, recipeId: String) -> String {
        guard let dir = storeDirectory() else { return "" }
        let imgDir = dir.appendingPathComponent(imagesDirectory)
        try? FileManager.default.createDirectory(at: imgDir, withIntermediateDirectories: true)
        let filePath = imgDir.appendingPathComponent("\(recipeId).jpg")
        do {
            try data.write(to: filePath)
            return filePath.path
        } catch {
            logger.error("Failed to save image for \(recipeId): \(error)")
            return ""
        }
    }

    public func imageFilePath(recipeId: String) -> String? {
        guard let dir = storeDirectory() else { return nil }
        let filePath = dir.appendingPathComponent(imagesDirectory).appendingPathComponent("\(recipeId).jpg")
        if FileManager.default.fileExists(atPath: filePath.path) {
            return filePath.path
        }
        return nil
    }

    public func deleteImage(recipeId: String) {
        guard let dir = storeDirectory() else { return }
        let filePath = dir.appendingPathComponent(imagesDirectory).appendingPathComponent("\(recipeId).jpg")
        try? FileManager.default.removeItem(at: filePath)
    }

    // MARK: - Favorites

    private let favoritesKey = "mealie_local_favorites"

    public func loadFavorites() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        return Set(array)
    }

    public func saveFavorites(_ favorites: Set<String>) {
        UserDefaults.standard.set(Array(favorites), forKey: favoritesKey)
    }

    public func addFavorite(slug: String) {
        var favorites = loadFavorites()
        favorites.insert(slug)
        saveFavorites(favorites)
    }

    public func removeFavorite(slug: String) {
        var favorites = loadFavorites()
        favorites.remove(slug)
        saveFavorites(favorites)
    }

    // MARK: - Helpers

    public func generateSlug(from name: String) -> String {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return slug.isEmpty ? "recipe" : slug
    }

    public func recipeCount() -> Int {
        loadAllRecipes().count
    }

    // MARK: - Private

    private func storeDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent(directoryName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func saveAllRecipes(_ recipes: [Recipe]) {
        guard let dir = storeDirectory() else { return }
        do {
            let data = try JSONEncoder().encode(recipes)
            let fileURL = dir.appendingPathComponent(recipesFilename)
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to save local recipes: \(error)")
        }
    }
}
