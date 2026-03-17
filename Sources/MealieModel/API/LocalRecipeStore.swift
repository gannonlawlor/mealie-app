import Foundation
import SkipFuse

private let logger = Log(category: "LocalStore")

/// Facade for recipe persistence. Delegates to SwiftData (iOS) or SQLite (Android)
/// internally, while keeping the same public API for all callers.
public class LocalRecipeStore: @unchecked Sendable {
    public static let shared = LocalRecipeStore()

    private let store: RecipePersistence
    private let imagesDirectory = "images"
    private let localDirectoryName = "mealie_local"

    private init() {
        #if !os(Android)
        let useCloudKit = AppSettings.shared.iCloudSync
            && FileManager.default.ubiquityIdentityToken != nil
        store = SwiftDataRecipeStore(useCloudKit: useCloudKit)
        #else
        store = AndroidSQLiteRecipeStore()
        #endif

        migrateFromFilesIfNeeded()
    }

    // MARK: - Recipes (delegated)

    public func loadAllRecipes() -> [Recipe] {
        store.loadAllRecipes()
    }

    public func loadRecipe(slug: String) -> Recipe? {
        store.loadRecipe(slug: slug)
    }

    public func saveRecipe(_ recipe: Recipe) {
        store.saveRecipe(recipe)
    }

    public func deleteRecipe(id: String) {
        store.deleteRecipe(id: id)
        deleteImage(recipeId: id)
    }

    public func recipeSummaries() -> [RecipeSummary] {
        store.recipeSummaries()
    }

    public func recipeCount() -> Int {
        store.recipeCount()
    }

    // MARK: - Search (delegated)

    public func findRecipeByOrgURL(_ url: String) -> Recipe? {
        store.findRecipeByOrgURL(url)
    }

    public func findRecipesByName(_ name: String) -> [Recipe] {
        store.findRecipesByName(name)
    }

    // MARK: - Favorites (delegated)

    public func loadFavorites() -> Set<String> {
        store.loadFavorites()
    }

    public func saveFavorites(_ favorites: Set<String>) {
        store.saveFavorites(favorites)
    }

    public func addFavorite(slug: String) {
        store.addFavorite(slug: slug)
    }

    public func removeFavorite(slug: String) {
        store.removeFavorite(slug: slug)
    }

    // MARK: - Images (file-based on both platforms)

    public func saveImage(data: Data, recipeId: String) -> String {
        guard let dir = localDirectory() else { return "" }
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
        guard let dir = localDirectory() else { return nil }
        let filePath = dir.appendingPathComponent(imagesDirectory).appendingPathComponent("\(recipeId).jpg")
        if FileManager.default.fileExists(atPath: filePath.path) {
            return filePath.path
        }
        return nil
    }

    public func deleteImage(recipeId: String) {
        guard let dir = localDirectory() else { return }
        let filePath = dir.appendingPathComponent(imagesDirectory).appendingPathComponent("\(recipeId).jpg")
        try? FileManager.default.removeItem(at: filePath)
    }

    // MARK: - Helpers

    public func generateSlug(from name: String) -> String {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return slug.isEmpty ? "recipe" : slug
    }

    // MARK: - Private

    private func localDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent(localDirectoryName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Migration from file-based storage

    private func migrateFromFilesIfNeeded() {
        let migrationKey = "mealie_db_migration_complete"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let fileStore = FileRecipeStore()

        // Migrate recipes from local file store
        let localRecipes = fileStore.loadAllRecipes()
        if !localRecipes.isEmpty {
            logger.info("Migrating \(localRecipes.count) recipes from files to database")
            for recipe in localRecipes {
                store.saveRecipe(recipe)
            }
        }

        // Also migrate from iCloud directory if it was previously used
        #if !os(Android)
        if AppSettings.shared.iCloudSync {
            migrateFromICloudFiles()
        }
        #endif

        // Migrate favorites
        let favorites = fileStore.loadFavorites()
        if !favorites.isEmpty {
            logger.info("Migrating \(favorites.count) favorites from files to database")
            store.saveFavorites(favorites)
        }

        // Also migrate favorites from legacy UserDefaults
        let legacyFavoritesKey = "mealie_local_favorites"
        let legacyArray = (UserDefaults.standard.object(forKey: legacyFavoritesKey) as? [String]) ?? []
        if !legacyArray.isEmpty {
            var allFavorites = store.loadFavorites()
            for slug in legacyArray {
                allFavorites.insert(slug)
            }
            store.saveFavorites(allFavorites)
            UserDefaults.standard.removeObject(forKey: legacyFavoritesKey)
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        logger.info("Migration from file-based storage complete")
    }

    #if !os(Android)
    private func migrateFromICloudFiles() {
        let containerID = "iCloud.com.jackabee.mealie"
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerID) else { return }
        let recipesDir = containerURL.appendingPathComponent("Documents/Recipes")
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: recipesDir, includingPropertiesForKeys: nil) else { return }

        var count = 0
        for file in files {
            guard file.lastPathComponent.hasPrefix("recipe_"),
                  file.pathExtension == "json" else { continue }
            guard let data = try? Data(contentsOf: file) else { continue }
            do {
                let recipe = try JSONDecoder().decode(Recipe.self, from: data)
                // Only save if not already in database (avoid overwriting local changes)
                if let slug = recipe.slug, store.loadRecipe(slug: slug) == nil {
                    store.saveRecipe(recipe)
                    count += 1
                }
            } catch {
                logger.error("Failed to decode iCloud recipe \(file.lastPathComponent): \(error)")
            }
        }
        if count > 0 {
            logger.info("Migrated \(count) recipes from iCloud files to database")
        }

        // Migrate iCloud favorites
        let favFile = recipesDir.appendingPathComponent("favorites.json")
        if let favData = try? Data(contentsOf: favFile),
           let slugs = try? JSONDecoder().decode([String].self, from: favData) {
            var existing = store.loadFavorites()
            for slug in slugs {
                existing.insert(slug)
            }
            store.saveFavorites(existing)
        }
    }
    #endif
}
