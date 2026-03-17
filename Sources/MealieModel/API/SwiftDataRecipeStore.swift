#if !os(Android)
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

    public init(useCloudKit: Bool = false) {
        let schema = Schema([RecipeEntity.self, FavoriteEntity.self])
        let config: ModelConfiguration
        if useCloudKit {
            config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.jackabee.mealie")
            )
        } else {
            config = ModelConfiguration(schema: schema)
        }
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
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

    public func saveRecipe(_ recipe: Recipe) {
        guard let id = recipe.id else { return }
        let data = try? JSONEncoder().encode(recipe)

        // Upsert: find existing or create new
        let descriptor = FetchDescriptor<RecipeEntity>(
            predicate: #Predicate<RecipeEntity> { entity in
                entity.recipeId == id
            }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.slug = recipe.slug
            existing.name = recipe.name
            existing.recipeData = data
            existing.dateUpdated = recipe.dateUpdated
        } else {
            let entity = RecipeEntity(
                recipeId: id,
                slug: recipe.slug,
                name: recipe.name,
                recipeData: data,
                dateUpdated: recipe.dateUpdated
            )
            modelContext.insert(entity)
        }

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save recipe \(id): \(error)")
        }
    }

    public func deleteRecipe(id: String) {
        let descriptor = FetchDescriptor<RecipeEntity>(
            predicate: #Predicate<RecipeEntity> { entity in
                entity.recipeId == id
            }
        )
        guard let entity = try? modelContext.fetch(descriptor).first else { return }
        modelContext.delete(entity)
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to delete recipe \(id): \(error)")
        }
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

    public func saveFavorites(_ favorites: Set<String>) {
        // Delete all existing favorites
        let descriptor = FetchDescriptor<FavoriteEntity>()
        if let existing = try? modelContext.fetch(descriptor) {
            for entity in existing {
                modelContext.delete(entity)
            }
        }
        // Insert new favorites
        for slug in favorites {
            modelContext.insert(FavoriteEntity(slug: slug))
        }
        try? modelContext.save()
    }

    public func addFavorite(slug: String) {
        // Check if already exists
        let descriptor = FetchDescriptor<FavoriteEntity>(
            predicate: #Predicate<FavoriteEntity> { entity in
                entity.slug == slug
            }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            return // Already a favorite
        }
        modelContext.insert(FavoriteEntity(slug: slug))
        try? modelContext.save()
    }

    public func removeFavorite(slug: String) {
        let descriptor = FetchDescriptor<FavoriteEntity>(
            predicate: #Predicate<FavoriteEntity> { entity in
                entity.slug == slug
            }
        )
        guard let entity = try? modelContext.fetch(descriptor).first else { return }
        modelContext.delete(entity)
        try? modelContext.save()
    }

    // MARK: - Private

    private func decodeRecipe(from entity: RecipeEntity) -> Recipe? {
        guard let data = entity.recipeData else { return nil }
        do {
            return try JSONDecoder().decode(Recipe.self, from: data)
        } catch {
            logger.error("Failed to decode recipe \(entity.recipeId): \(error)")
            return nil
        }
    }
}
#endif
