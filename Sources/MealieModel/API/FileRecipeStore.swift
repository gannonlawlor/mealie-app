import Foundation
import SkipFuse

private let logger = Log(category: "FileStore")

/// File-based recipe storage (original implementation).
/// Kept for migration from files to database and as test-friendly store.
public class FileRecipeStore: RecipePersistence, @unchecked Sendable {
    private let directoryName = "mealie_local"
    private let favoritesFilename = "favorites.json"

    public init() {}

    // MARK: - Recipes

    public func loadAllRecipes() -> [Recipe] {
        guard let dir = storeDirectory() else { return [] }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        var recipes: [Recipe] = []
        for file in files {
            guard file.lastPathComponent.hasPrefix("recipe_"),
                  file.pathExtension == "json" else { continue }
            guard let data = try? Data(contentsOf: file) else { continue }
            do {
                let recipe = try JSONDecoder().decode(Recipe.self, from: data)
                recipes.append(recipe)
            } catch {
                logger.error("Failed to decode recipe file \(file.lastPathComponent): \(error)")
            }
        }
        return recipes
    }

    public func loadRecipe(slug: String) -> Recipe? {
        loadAllRecipes().first { $0.slug == slug }
    }

    public func saveRecipe(_ recipe: Recipe) {
        guard let dir = storeDirectory(), let id = recipe.id else { return }
        let fileURL = dir.appendingPathComponent("recipe_\(id).json")
        do {
            let data = try JSONEncoder().encode(recipe)
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to save recipe \(id): \(error)")
        }
    }

    public func deleteRecipe(id: String) {
        guard let dir = storeDirectory() else { return }
        let fileURL = dir.appendingPathComponent("recipe_\(id).json")
        try? FileManager.default.removeItem(at: fileURL)
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
        guard let dir = storeDirectory() else { return 0 }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return 0
        }
        return files.filter { $0.lastPathComponent.hasPrefix("recipe_") && $0.pathExtension == "json" }.count
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
        guard let dir = storeDirectory() else { return [] }
        let fileURL = dir.appendingPathComponent(favoritesFilename)
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            let array = try JSONDecoder().decode([String].self, from: data)
            return Set(array)
        } catch {
            logger.error("Failed to decode favorites: \(error)")
            return []
        }
    }

    public func saveFavorites(_ favorites: Set<String>) {
        guard let dir = storeDirectory() else { return }
        let fileURL = dir.appendingPathComponent(favoritesFilename)
        do {
            let data = try JSONEncoder().encode(Array(favorites))
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to save favorites: \(error)")
        }
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

    // MARK: - Directory

    public func storeDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent(directoryName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Check if there are any recipe files in the store directory.
    public func hasRecipeFiles() -> Bool {
        guard let dir = storeDirectory() else { return false }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return false
        }
        return files.contains { $0.lastPathComponent.hasPrefix("recipe_") && $0.pathExtension == "json" }
    }

    /// Check if a favorites file exists.
    public func hasFavoritesFile() -> Bool {
        guard let dir = storeDirectory() else { return false }
        let fileURL = dir.appendingPathComponent(favoritesFilename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}
