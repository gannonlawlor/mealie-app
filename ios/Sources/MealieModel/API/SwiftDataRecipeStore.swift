import Foundation
import SwiftData

// MARK: - SwiftData Models

@Model
final class RecipeEntity {
    var recipeId: String = ""
    var slug: String? = nil
    var name: String? = nil
    var recipeData: Data? = nil
    var dateUpdated: String? = nil
    @Attribute(.externalStorage) var imageData: Data? = nil

    init(recipeId: String, slug: String?, name: String?, recipeData: Data?, dateUpdated: String?) {
        self.recipeId = recipeId
        self.slug = slug
        self.name = name
        self.recipeData = recipeData
        self.dateUpdated = dateUpdated
    }
}

@Model
final class FavoriteEntity {
    var slug: String = ""

    init(slug: String) {
        self.slug = slug
    }
}

// MARK: - SwiftData Recipe Store

private let logger = Log(category: "SwiftDataStore")

public class SwiftDataRecipeStore: RecipePersistence, @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    public init(useCloudKit: Bool = false, configuration: ModelConfiguration? = nil) throws {
        let schema = Schema([RecipeEntity.self, FavoriteEntity.self])
        let config: ModelConfiguration
        if let configuration {
            config = configuration
        } else if useCloudKit {
            config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.jackabee.mealie")
            )
        } else {
            config = ModelConfiguration(schema: schema)
        }
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
        try backfillImageData()
    }

    /// Additive migration: retain original files while attaching their bytes to
    /// records so CloudKit can transport photos alongside the recipe data.
    private func backfillImageData() throws {
        let entities = try modelContext.fetch(FetchDescriptor<RecipeEntity>())
        for entity in entities where entity.imageData == nil {
            guard let data = entity.recipeData,
                  let recipe = try? JSONDecoder().decode(Recipe.self, from: data),
                  let bytes = RecipeImageFiles.readLocalImage(recipe.image) else { continue }
            entity.imageData = bytes
            entity.recipeData = try JSONEncoder().encode(recipe.replacingImage(nil))
        }
        if modelContext.hasChanges { try saveChanges() }
    }

    private func saveChanges() throws {
        do { try modelContext.save() }
        catch {
            modelContext.rollback()
            throw error
        }
    }

    // MARK: - Recipes

    public func loadAllRecipes() -> [Recipe] {
        let descriptor = FetchDescriptor<RecipeEntity>()
        guard let entities = try? modelContext.fetch(descriptor) else { return [] }
        return entities.compactMap { decodeRecipe(from: $0) }
    }

    public func loadRecipe(slug: String) -> Recipe? {
        let descriptor = FetchDescriptor<RecipeEntity>(
            predicate: #Predicate<RecipeEntity> { entity in
                entity.slug == slug
            }
        )
        guard let entity = try? modelContext.fetch(descriptor).first else { return nil }
        return decodeRecipe(from: entity)
    }

    public func saveRecipe(_ recipe: Recipe) throws {
        guard let id = recipe.id else { throw RecipeStorageError.missingRecipeID }
        let descriptor = FetchDescriptor<RecipeEntity>(
            predicate: #Predicate<RecipeEntity> { $0.recipeId == id }
        )
        let existing = try modelContext.fetch(descriptor).first
        let imageData = RecipeImageFiles.readLocalImage(recipe.image)
        // Absolute sandbox paths are never portable between devices.
        let portable = RecipeImageFiles.isLocalPath(recipe.image)
            ? recipe.replacingImage(nil) : recipe
        let data = try JSONEncoder().encode(portable)
        let entity = existing ?? RecipeEntity(recipeId: id, slug: recipe.slug,
            name: recipe.name, recipeData: data, dateUpdated: recipe.dateUpdated)
        entity.slug = recipe.slug
        entity.name = recipe.name
        entity.recipeData = data
        entity.dateUpdated = recipe.dateUpdated
        if let imageData {
            entity.imageData = imageData
        } else if !RecipeImageFiles.isLocalPath(recipe.image) {
            // A remote replacement or explicit removal must not resurrect an
            // older embedded photo when the record is decoded.
            entity.imageData = nil
        }
        if existing == nil { modelContext.insert(entity) }
        try saveChanges()
    }

    public func deleteRecipe(id: String) throws {
        let descriptor = FetchDescriptor<RecipeEntity>(
            predicate: #Predicate<RecipeEntity> { $0.recipeId == id }
        )
        guard let entity = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(entity)
        try saveChanges()
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
        let descriptor = FetchDescriptor<RecipeEntity>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Search

    public func findRecipeByOrgURL(_ url: String) -> Recipe? {
        // orgURL is not indexed — load all and filter
        loadAllRecipes().first { $0.orgURL == url }
    }

    public func findRecipesByName(_ name: String) -> [Recipe] {
        let query = name.lowercased()
        let descriptor = FetchDescriptor<RecipeEntity>(
            predicate: #Predicate<RecipeEntity> { entity in
                entity.name == query
            }
        )
        guard let entities = try? modelContext.fetch(descriptor) else { return [] }
        // SwiftData predicate is case-sensitive, so also filter in-memory for lowercased match
        return loadAllRecipes().filter { ($0.name ?? "").lowercased() == query }
    }

    // MARK: - Favorites

    public func loadFavorites() -> Set<String> {
        let descriptor = FetchDescriptor<FavoriteEntity>()
        guard let entities = try? modelContext.fetch(descriptor) else { return [] }
        return Set(entities.map { $0.slug })
    }

    public func saveFavorites(_ favorites: Set<String>) throws {
        let existing = try modelContext.fetch(FetchDescriptor<FavoriteEntity>())
        for entity in existing { modelContext.delete(entity) }
        for slug in favorites { modelContext.insert(FavoriteEntity(slug: slug)) }
        try saveChanges()
    }

    public func addFavorite(slug: String) throws {
        let descriptor = FetchDescriptor<FavoriteEntity>(
            predicate: #Predicate<FavoriteEntity> { $0.slug == slug }
        )
        if try !modelContext.fetch(descriptor).isEmpty { return }
        modelContext.insert(FavoriteEntity(slug: slug))
        try saveChanges()
    }

    public func removeFavorite(slug: String) throws {
        let descriptor = FetchDescriptor<FavoriteEntity>(
            predicate: #Predicate<FavoriteEntity> { $0.slug == slug }
        )
        guard let entity = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(entity)
        try saveChanges()
    }

    // MARK: - Private

    private func decodeRecipe(from entity: RecipeEntity) -> Recipe? {
        guard let data = entity.recipeData else { return nil }
        do {
            let recipe = try JSONDecoder().decode(Recipe.self, from: data)
            if let bytes = entity.imageData,
               let path = try? RecipeImageFiles.write(bytes, recipeId: entity.recipeId) {
                return recipe.replacingImage(path)
            }
            return recipe
        } catch {
            logger.error("Failed to decode recipe \(entity.recipeId): \(error)")
            return nil
        }
    }
}
