import Foundation
import SkipFuse

private let logger = Log(category: "LocalStore")

public class LocalRecipeStore: @unchecked Sendable {
    public static let shared = LocalRecipeStore()

    private let directoryName = "mealie_local"
    private let imagesDirectory = "images"
    private let favoritesFilename = "favorites.json"
    private let legacyRecipesFilename = "recipes.json"
    private let legacyFavoritesKey = "mealie_local_favorites"

    private var customRootDirectory: URL?

    private init() {
        migrateIfNeeded()
    }

    // MARK: - Directory Configuration

    public func setRootDirectory(_ url: URL?) {
        customRootDirectory = url
        if url != nil {
            // Ensure the directory exists
            try? FileManager.default.createDirectory(at: url!, withIntermediateDirectories: true)
            let imgDir = url!.appendingPathComponent(imagesDirectory)
            try? FileManager.default.createDirectory(at: imgDir, withIntermediateDirectories: true)
        }
    }

    public func rootDirectory() -> URL? {
        if let custom = customRootDirectory {
            return custom
        }
        return defaultDirectory()
    }

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

    // MARK: - Favorites (file-based)

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

    // MARK: - Duplicate Detection

    public func findRecipeByOrgURL(_ url: String) -> Recipe? {
        loadAllRecipes().first { $0.orgURL == url }
    }

    public func findRecipesByName(_ name: String) -> [Recipe] {
        let query = name.lowercased()
        return loadAllRecipes().filter { ($0.name ?? "").lowercased() == query }
    }

    // MARK: - Helpers

    public func generateSlug(from name: String) -> String {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return slug.isEmpty ? "recipe" : slug
    }

    public func recipeCount() -> Int {
        guard let dir = storeDirectory() else { return 0 }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return 0
        }
        return files.filter { $0.lastPathComponent.hasPrefix("recipe_") && $0.pathExtension == "json" }.count
    }

    // MARK: - Migration

    public func copyAllFiles(to destination: URL) {
        guard let dir = storeDirectory() else { return }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            let destFile = destination.appendingPathComponent(file.lastPathComponent)
            if file.lastPathComponent == imagesDirectory {
                // Copy entire images directory
                if fm.fileExists(atPath: destFile.path) {
                    try? fm.removeItem(at: destFile)
                }
                try? fm.copyItem(at: file, to: destFile)
            } else if file.pathExtension == "json" {
                try? fm.copyItem(at: file, to: destFile)
            }
        }
    }

    // MARK: - Private

    private func defaultDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent(directoryName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func storeDirectory() -> URL? {
        if let custom = customRootDirectory {
            return custom
        }
        return defaultDirectory()
    }

    private func migrateIfNeeded() {
        migrateFromSingleFile()
        migrateFavoritesFromUserDefaults()
    }

    private func migrateFromSingleFile() {
        guard let dir = defaultDirectory() else { return }
        let legacyFile = dir.appendingPathComponent(legacyRecipesFilename)
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyFile.path) else { return }

        logger.info("Migrating from single recipes.json to per-recipe files")
        guard let data = try? Data(contentsOf: legacyFile) else {
            try? fm.removeItem(at: legacyFile)
            return
        }
        do {
            let recipes = try JSONDecoder().decode([Recipe].self, from: data)
            for recipe in recipes {
                guard let id = recipe.id else { continue }
                let fileURL = dir.appendingPathComponent("recipe_\(id).json")
                let recipeData = try JSONEncoder().encode(recipe)
                try recipeData.write(to: fileURL)
            }
            try fm.removeItem(at: legacyFile)
            logger.info("Migration complete: \(recipes.count) recipes migrated")
        } catch {
            logger.error("Migration from recipes.json failed: \(error)")
        }
    }

    private func migrateFavoritesFromUserDefaults() {
        guard let dir = defaultDirectory() else { return }
        let favFile = dir.appendingPathComponent(favoritesFilename)
        let fm = FileManager.default

        // Only migrate if file doesn't exist yet and UserDefaults has data
        guard !fm.fileExists(atPath: favFile.path) else { return }
        let array = (UserDefaults.standard.object(forKey: legacyFavoritesKey) as? [String]) ?? []
        guard !array.isEmpty else { return }

        logger.info("Migrating favorites from UserDefaults to file")
        do {
            let data = try JSONEncoder().encode(array)
            try data.write(to: favFile)
            UserDefaults.standard.removeObject(forKey: legacyFavoritesKey)
            logger.info("Favorites migration complete: \(array.count) favorites")
        } catch {
            logger.error("Favorites migration failed: \(error)")
        }
    }
}
