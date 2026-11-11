import Foundation

private let logger = Log(category: "OfflineStore")

public class OfflineRecipeStore: @unchecked Sendable {
    public static let shared = OfflineRecipeStore()

    private let directoryName = "mealie_offline"
    private let imagesDirectory = "images"
    private let idsKey = "mealie_offline_recipe_ids"

    private let defaults: UserDefaults
    private let directory: URL?
    init(defaults: UserDefaults = .standard, directory: URL? = nil) {
        self.defaults = defaults; self.directory = directory
    }

    // MARK: - Save / Load

    public func saveRecipe(_ recipe: Recipe, imageData: Data?) throws {
        guard let dir = storeDirectory(), let id = recipe.id else { throw RecipeStorageError.unavailable }
        let data = try JSONEncoder().encode(recipe)
        // Publish the saved marker only after all requested content is durable.
        if let imageData {
            let imgDir = dir.appendingPathComponent(imagesDirectory)
            try FileManager.default.createDirectory(at: imgDir, withIntermediateDirectories: true)
            try imageData.write(to: imgDir.appendingPathComponent("\(id).jpg"), options: .atomic)
        }
        try data.write(to: dir.appendingPathComponent("recipe_\(id).json"), options: .atomic)
        var ids = savedRecipeIds()
        ids.insert(id)
        saveSavedIds(ids)
    }

    public func loadRecipe(id: String) -> Recipe? {
        guard let dir = storeDirectory() else { return nil }
        let fileURL = dir.appendingPathComponent("recipe_\(id).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try JSONDecoder().decode(Recipe.self, from: data)
        } catch {
            logger.error("Failed to decode offline recipe \(id): \(error)")
            return nil
        }
    }

    public func loadRecipeBySlug(slug: String) -> Recipe? {
        for id in savedRecipeIds() {
            if let recipe = loadRecipe(id: id), recipe.slug == slug {
                return recipe
            }
        }
        return nil
    }

    public func loadAllSavedRecipes() -> [Recipe] {
        var recipes: [Recipe] = []
        for id in savedRecipeIds() {
            if let recipe = loadRecipe(id: id) {
                recipes.append(recipe)
            }
        }
        return recipes
    }

    public func removeRecipe(id: String) {
        guard let dir = storeDirectory() else { return }
        let fileURL = dir.appendingPathComponent("recipe_\(id).json")
        try? FileManager.default.removeItem(at: fileURL)

        let imgPath = dir.appendingPathComponent(imagesDirectory).appendingPathComponent("\(id).jpg")
        try? FileManager.default.removeItem(at: imgPath)

        var ids = savedRecipeIds()
        ids.remove(id)
        saveSavedIds(ids)
    }

    // MARK: - Image

    public func replaceImageIfSaved(id: String, data: Data) throws {
        guard isRecipeSavedOffline(id: id), let dir = storeDirectory() else { return }
        let images = dir.appendingPathComponent(imagesDirectory)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try data.write(to: images.appendingPathComponent("\(id).jpg"), options: .atomic)
    }

    public func imageFilePath(recipeId: String) -> String? {
        guard let dir = storeDirectory() else { return nil }
        let filePath = dir.appendingPathComponent(imagesDirectory).appendingPathComponent("\(recipeId).jpg")
        if FileManager.default.fileExists(atPath: filePath.path) {
            return filePath.path
        }
        return nil
    }

    // MARK: - ID Tracking

    public func isRecipeSavedOffline(id: String) -> Bool {
        savedRecipeIds().contains(id)
    }

    public func savedRecipeIds() -> Set<String> {
        let array = (defaults.object(forKey: idsKey) as? [String]) ?? []
        return Set(array.filter { loadRecipe(id: $0) != nil })
    }

    // MARK: - Clear

    public func clearAll() {
        guard let dir = storeDirectory() else { return }
        try? FileManager.default.removeItem(at: dir)
        defaults.removeObject(forKey: idsKey)
    }

    // MARK: - Private

    private func saveSavedIds(_ ids: Set<String>) {
        defaults.set(Array(ids), forKey: idsKey)
    }

    private func storeDirectory() -> URL? {
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent(directoryName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
