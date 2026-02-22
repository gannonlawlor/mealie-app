import Foundation
import Observation
import SkipFuse

private let logger = Log(category: "Recipes")

@MainActor @Observable public class RecipeViewModel {
    public var recipes: [RecipeSummary] = []
    public var selectedRecipe: Recipe? = nil
    public var categories: [RecipeCategory] = []
    public var tags: [RecipeTag] = []
    public var isLoading: Bool = false
    public var isLoadingDetail: Bool = false
    public var searchText: String = ""
    public var selectedCategory: RecipeCategory? = nil
    public var selectedTag: RecipeTag? = nil
    public var currentPage: Int = 1
    public var totalPages: Int = 1
    public var errorMessage: String = ""

    // Import
    public var importURL: String = ""
    public var isImporting: Bool = false
    public var importMessage: String = ""

    // Local mode
    public var isLocalMode: Bool = false

    public init() {}

    public func loadRecipes(reset: Bool = false) async {
        if isLocalMode {
            isLoading = true
            var all = LocalRecipeStore.shared.recipeSummaries()
            // Filter by search
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                all = all.filter { ($0.name ?? "").lowercased().contains(query) || ($0.description ?? "").lowercased().contains(query) }
            }
            // Filter by category
            if let cat = selectedCategory {
                all = all.filter { ($0.recipeCategory ?? []).contains(where: { $0.slug == cat.slug }) }
            }
            // Filter by tag
            if let tag = selectedTag {
                all = all.filter { ($0.tags ?? []).contains(where: { $0.slug == tag.slug }) }
            }
            recipes = all
            totalPages = 1
            currentPage = 1
            isLoading = false
            return
        }

        if reset {
            currentPage = 1
            // Show cached data immediately on first load
            if recipes.isEmpty, searchText.isEmpty, selectedCategory == nil, selectedTag == nil {
                if let cached = CacheService.shared.loadRecipeList() {
                    recipes = cached
                }
            } else {
                recipes = []
            }
        }

        isLoading = true
        errorMessage = ""

        do {
            let response = try await MealieAPI.shared.getRecipes(
                page: currentPage,
                perPage: 30,
                search: searchText.isEmpty ? nil : searchText,
                categories: selectedCategory?.id != nil ? [selectedCategory!.id!] : nil,
                tags: selectedTag?.id != nil ? [selectedTag!.id!] : nil
            )
            if reset {
                recipes = response.items
                // Cache unfiltered first page
                if searchText.isEmpty && selectedCategory == nil && selectedTag == nil {
                    CacheService.shared.saveRecipeList(response.items)
                }
            } else {
                recipes.append(contentsOf: response.items)
            }
            totalPages = response.totalPages
            isLoading = false
        } catch {
            errorMessage = "Failed to load recipes."
            logger.error("Failed to load recipes: \(error)")
            isLoading = false
        }
    }

    public func loadNextPage() async {
        guard currentPage < totalPages, !isLoading else { return }
        currentPage += 1
        await loadRecipes()
    }

    public func loadRecipeDetail(slug: String) async {
        if isLocalMode {
            selectedRecipe = LocalRecipeStore.shared.loadRecipe(slug: slug)
            isLoadingDetail = false
            return
        }

        // Show cached detail immediately
        if let cached = CacheService.shared.loadRecipeDetail(slug: slug) {
            selectedRecipe = cached
        }

        isLoadingDetail = selectedRecipe == nil
        do {
            let recipe = try await MealieAPI.shared.getRecipe(slug: slug)
            selectedRecipe = recipe
            CacheService.shared.saveRecipeDetail(recipe, slug: slug)
            isLoadingDetail = false
        } catch {
            if selectedRecipe == nil {
                errorMessage = "Failed to load recipe."
            }
            logger.error("Failed to load recipe detail: \(error)")
            isLoadingDetail = false
        }
    }

    public func loadCategories() async {
        if isLocalMode {
            var seen = Set<String>()
            var result: [RecipeCategory] = []
            for recipe in LocalRecipeStore.shared.loadAllRecipes() {
                for cat in recipe.recipeCategory ?? [] {
                    if let slug = cat.slug, !seen.contains(slug) {
                        seen.insert(slug)
                        result.append(cat)
                    }
                }
            }
            categories = result
            return
        }

        if categories.isEmpty, let cached = CacheService.shared.loadCategories() {
            categories = cached
        }
        do {
            let response = try await MealieAPI.shared.getCategories()
            categories = response.items
            CacheService.shared.saveCategories(response.items)
        } catch {
            logger.error("Failed to load categories: \(error)")
        }
    }

    public func loadTags() async {
        if isLocalMode {
            var seen = Set<String>()
            var result: [RecipeTag] = []
            for recipe in LocalRecipeStore.shared.loadAllRecipes() {
                for tag in recipe.tags ?? [] {
                    if let slug = tag.slug, !seen.contains(slug) {
                        seen.insert(slug)
                        result.append(tag)
                    }
                }
            }
            tags = result
            return
        }

        if tags.isEmpty, let cached = CacheService.shared.loadTags() {
            tags = cached
        }
        do {
            let response = try await MealieAPI.shared.getTags()
            tags = response.items
            CacheService.shared.saveTags(response.items)
        } catch {
            logger.error("Failed to load tags: \(error)")
        }
    }

    public func deleteRecipe(slug: String) async -> Bool {
        if isLocalMode {
            if let recipe = LocalRecipeStore.shared.loadRecipe(slug: slug), let id = recipe.id {
                LocalRecipeStore.shared.deleteRecipe(id: id)
            }
            recipes.removeAll { $0.slug == slug }
            return true
        }

        do {
            try await MealieAPI.shared.deleteRecipe(slug: slug)
            recipes.removeAll { $0.slug == slug }
            return true
        } catch {
            errorMessage = "Failed to delete recipe."
            logger.error("Failed to delete recipe: \(error)")
            return false
        }
    }

    public func importFromURL() async {
        guard !importURL.isEmpty else { return }
        isImporting = true
        importMessage = ""

        if isLocalMode {
            do {
                let recipe = try await RecipeURLParser.shared.parseRecipe(from: importURL)
                LocalRecipeStore.shared.saveRecipe(recipe)
                importMessage = "Recipe imported successfully!"
                importURL = ""
                isImporting = false
                await loadRecipes(reset: true)
            } catch let error as RecipeParseError {
                switch error {
                case .invalidURL:
                    importMessage = "Invalid URL."
                case .fetchFailed(let msg):
                    importMessage = "Could not fetch page: \(msg)"
                case .noRecipeFound:
                    importMessage = "No recipe found on that page."
                case .parsingFailed(let msg):
                    importMessage = "Failed to parse recipe: \(msg)"
                }
                logger.error("Local import error: \(error)")
                isImporting = false
            } catch {
                importMessage = "Failed to import recipe."
                logger.error("Local import error: \(error)")
                isImporting = false
            }
            return
        }

        do {
            let slug = try await MealieAPI.shared.createRecipeFromURL(url: importURL)
            importMessage = "Recipe imported successfully!"
            importURL = ""
            isImporting = false
            // Reload to show the new recipe
            await loadRecipes(reset: true)
        } catch {
            importMessage = "Failed to import recipe. Check the URL."
            logger.error("Failed to import recipe: \(error)")
            isImporting = false
        }
    }

    public func search() async {
        await loadRecipes(reset: true)
    }

    // MARK: - Favorites

    public var favoriteRecipes: Set<String> = []

    public func loadFavorites(user: User?) {
        guard let slugs = user?.favoriteRecipes else { return }
        favoriteRecipes = Set(slugs)
    }

    public func isFavorite(slug: String) -> Bool {
        favoriteRecipes.contains(slug)
    }

    public func toggleFavorite(slug: String, userId: String) async {
        let wasFavorite = favoriteRecipes.contains(slug)
        // Optimistic update
        if wasFavorite {
            favoriteRecipes.remove(slug)
        } else {
            favoriteRecipes.insert(slug)
        }

        do {
            if wasFavorite {
                try await MealieAPI.shared.removeFavorite(userId: userId, slug: slug)
            } else {
                try await MealieAPI.shared.addFavorite(userId: userId, slug: slug)
            }
        } catch {
            // Revert on failure
            if wasFavorite {
                favoriteRecipes.insert(slug)
            } else {
                favoriteRecipes.remove(slug)
            }
            errorMessage = "Failed to update favorite."
            logger.error("Failed to toggle favorite: \(error)")
        }
    }

    // MARK: - Update Recipe

    public func updateRecipe(slug: String, data: Recipe) async -> Bool {
        if isLocalMode {
            LocalRecipeStore.shared.saveRecipe(data)
            selectedRecipe = data
            await loadRecipes(reset: true)
            return true
        }

        do {
            selectedRecipe = try await MealieAPI.shared.updateRecipe(slug: slug, data: data)
            await loadRecipes(reset: true)
            return true
        } catch {
            errorMessage = "Failed to update recipe."
            logger.error("Failed to update recipe: \(error)")
            return false
        }
    }

    public func createLocalRecipe(name: String) async -> Recipe {
        let id = UUID().uuidString
        let slug = LocalRecipeStore.shared.generateSlug(from: name)
        let now = ISO8601DateFormatter().string(from: Date())

        let recipe = Recipe(
            id: id, slug: slug, name: name, description: nil, image: nil,
            recipeCategory: nil, tags: nil, tools: nil, rating: nil,
            recipeYield: nil, recipeIngredient: nil, recipeInstructions: nil,
            totalTime: nil, prepTime: nil, performTime: nil, nutrition: nil,
            settings: nil, dateAdded: now, dateUpdated: now,
            createdAt: now, updatedAt: now, orgURL: nil, extras: nil
        )
        LocalRecipeStore.shared.saveRecipe(recipe)
        await loadRecipes(reset: true)
        return recipe
    }
}
