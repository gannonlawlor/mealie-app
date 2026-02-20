import Foundation
import Observation
import OSLog
import SkipFuse

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

    public init() {}

    public func loadRecipes(reset: Bool = false) async {
        if reset {
            currentPage = 1
            recipes = []
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
        isLoadingDetail = true
        do {
            selectedRecipe = try await MealieAPI.shared.getRecipe(slug: slug)
            isLoadingDetail = false
        } catch {
            logger.error("Failed to load recipe detail: \(error)")
            isLoadingDetail = false
        }
    }

    public func loadCategories() async {
        do {
            let response = try await MealieAPI.shared.getCategories()
            categories = response.items
        } catch {
            logger.error("Failed to load categories: \(error)")
        }
    }

    public func loadTags() async {
        do {
            let response = try await MealieAPI.shared.getTags()
            tags = response.items
        } catch {
            logger.error("Failed to load tags: \(error)")
        }
    }

    public func deleteRecipe(slug: String) async -> Bool {
        do {
            try await MealieAPI.shared.deleteRecipe(slug: slug)
            recipes.removeAll { $0.slug == slug }
            return true
        } catch {
            logger.error("Failed to delete recipe: \(error)")
            return false
        }
    }

    public func importFromURL() async {
        guard !importURL.isEmpty else { return }
        isImporting = true
        importMessage = ""

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
}
