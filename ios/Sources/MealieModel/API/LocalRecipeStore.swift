import Foundation
import Observation

private let logger = Log(category: "LocalStore")

/// Facade for recipe persistence. Delegates to SwiftData (iOS) or SQLite (Android)
/// internally, while keeping the same public API for all callers.
@Observable public class LocalRecipeStore: @unchecked Sendable {
    public static let shared = LocalRecipeStore()

    @ObservationIgnored private var store: RecipePersistence?
    @ObservationIgnored private var performMigration = true
    public private(set) var initializationError: String?

    @ObservationIgnored private var makeStore: () throws -> RecipePersistence = {
        let useCloudKit = AppSettings.shared.iCloudSync
            && FileManager.default.ubiquityIdentityToken != nil
        return try SwiftDataRecipeStore(useCloudKit: useCloudKit)
    }

    private init() { retryOpeningLibrary() }

    init(performMigration: Bool = false, makeStore: @escaping () throws -> RecipePersistence) {
        self.performMigration = performMigration
        self.makeStore = makeStore
        retryOpeningLibrary()
    }

    /// Retrying never removes or replaces an existing database.
    public func retryOpeningLibrary() {
        do {
            if store == nil {
                store = try makeStore()
            }
            if performMigration { try migrateFromFilesIfNeeded() }
            initializationError = nil
        } catch {
            initializationError = error.localizedDescription
            logger.error("Recipe library unavailable: \(error)")
        }
    }

    init(store: RecipePersistence) { self.store = store }

    private func writableStore() throws -> RecipePersistence {
        guard let store, initializationError == nil else { throw RecipeStorageError.unavailable }
        return store
    }

    // MARK: - Recipes (delegated)

    public func loadAllRecipes() -> [Recipe] {
        store?.loadAllRecipes() ?? []
    }

    public func loadRecipe(slug: String) -> Recipe? {
        store?.loadRecipe(slug: slug)
    }

    public func saveRecipe(_ recipe: Recipe) throws {
        try writableStore().saveRecipe(recipe)
    }

    public func deleteRecipe(id: String) throws {
        try writableStore().deleteRecipe(id: id)
        deleteImage(recipeId: id)
    }

    public func recipeSummaries() -> [RecipeSummary] {
        store?.recipeSummaries() ?? []
    }

    public func recipeCount() -> Int {
        store?.recipeCount() ?? 0
    }

    // MARK: - Search (delegated)

    public func findRecipeByOrgURL(_ url: String) -> Recipe? {
        store?.findRecipeByOrgURL(url)
    }

    public func findRecipesByName(_ name: String) -> [Recipe] {
        store?.findRecipesByName(name) ?? []
    }

    // MARK: - Favorites (delegated)

    public func loadFavorites() -> Set<String> {
        store?.loadFavorites() ?? []
    }

    public func saveFavorites(_ favorites: Set<String>) throws {
        try writableStore().saveFavorites(favorites)
    }

    public func addFavorite(slug: String) throws {
        try writableStore().addFavorite(slug: slug)
    }

    public func removeFavorite(slug: String) throws {
        try writableStore().removeFavorite(slug: slug)
    }

    // MARK: - Images (file-based on both platforms)

    public func saveImage(data: Data, recipeId: String) -> String {
        do { return try RecipeImageFiles.write(data, recipeId: recipeId) }
        catch {
            logger.error("Failed to save recipe image: \(error)")
            return ""
        }
    }

    public func imageFilePath(recipeId: String) -> String? {
        guard let url = try? RecipeImageFiles.url(recipeId: recipeId),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url.path
    }

    public func deleteImage(recipeId: String) {
        guard let url = try? RecipeImageFiles.url(recipeId: recipeId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    public func saveRecipeImage(_ data: Data, recipe: Recipe) throws {
        guard let id = recipe.id else { throw RecipeStorageError.missingRecipeID }
        let path = try RecipeImageFiles.write(data, recipeId: id)
        try saveRecipe(recipe.replacingImage(path))
    }

    // MARK: - Helpers

    public func generateSlug(from name: String) -> String {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return slug.isEmpty ? "recipe" : slug
    }

    // MARK: - Migration from file-based storage

    private func migrateFromFilesIfNeeded() throws {
        guard let store else { throw RecipeStorageError.unavailable }
        let migrationKey = "mealie_db_migration_complete"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let fileStore = FileRecipeStore()

        // Migrate recipes from local file store
        let localRecipes = fileStore.loadAllRecipes()
        if !localRecipes.isEmpty {
            logger.info("Migrating \(localRecipes.count) recipes from files to database")
            for recipe in localRecipes {
                try store.saveRecipe(recipe)
            }
        }

        // Also migrate from iCloud directory if it was previously used
        if AppSettings.shared.iCloudSync {
            try migrateFromICloudFiles()
        }

        // Migrate favorites
        let favorites = fileStore.loadFavorites()
        if !favorites.isEmpty {
            logger.info("Migrating \(favorites.count) favorites from files to database")
            try store.saveFavorites(favorites)
        }

        // Also migrate favorites from legacy UserDefaults
        let legacyFavoritesKey = "mealie_local_favorites"
        let legacyArray = (UserDefaults.standard.object(forKey: legacyFavoritesKey) as? [String]) ?? []
        if !legacyArray.isEmpty {
            var allFavorites = store.loadFavorites()
            for slug in legacyArray {
                allFavorites.insert(slug)
            }
            try store.saveFavorites(allFavorites)
            UserDefaults.standard.removeObject(forKey: legacyFavoritesKey)
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        logger.info("Migration from file-based storage complete")
    }

    private func migrateFromICloudFiles() throws {
        guard let store else { throw RecipeStorageError.unavailable }
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
                    try store.saveRecipe(recipe)
                    count += 1
                }
            } catch {
                logger.error("Failed to migrate iCloud recipe \(file.lastPathComponent): \(error)")
                throw error
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
            try store.saveFavorites(existing)
        }
    }
}
