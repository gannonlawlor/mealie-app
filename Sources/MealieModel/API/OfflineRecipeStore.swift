import Foundation
import SkipFuse

private let logger = Log(category: "OfflineStore")

public class OfflineRecipeStore: @unchecked Sendable {
    public static let shared = OfflineRecipeStore()

    private let directoryName = "mealie_offline"
    private let imagesDirectory = "images"
    private let idsKey = "mealie_offline_recipe_ids"

    private init() {}

    // MARK: - Save / Load

    public func saveRecipe(_ recipe: Recipe, imageData: Data?) {
        guard let dir = storeDirectory(), let id = recipe.id else { return }
        let fileURL = dir.appendingPathComponent("recipe_\(id).json")
        do {
            let data = try JSONEncoder().encode(recipe)
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to save offline recipe \(id): \(error)")
            return
        }

        if let imageData = imageData {
            let imgDir = dir.appendingPathComponent(imagesDirectory)
            try? FileManager.default.createDirectory(at: imgDir, withIntermediateDirectories: true)
            let imgPath = imgDir.appendingPathComponent("\(id).jpg")
            do {
                try imageData.write(to: imgPath)
            } catch {
                logger.error("Failed to save offline image for \(id): \(error)")
            }
        }

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
        let array = UserDefaults.standard.stringArray(forKey: idsKey) ?? []
        return Set(array)
    }

    // MARK: - Clear

    public func clearAll() {
        guard let dir = storeDirectory() else { return }
        try? FileManager.default.removeItem(at: dir)
        UserDefaults.standard.removeObject(forKey: idsKey)
    }

    // MARK: - Private

    private func saveSavedIds(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: idsKey)
    }

    private func storeDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent(directoryName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
