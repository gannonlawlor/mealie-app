import Foundation
import Observation

private let logger = Log(category: "Recipes")

@MainActor @Observable public class RecipeViewModel {
    public var recipes: [RecipeSummary] = []
    public var selectedRecipe: Recipe? = nil
    public var categories: [RecipeCategory] = []
    public var tags: [RecipeTag] = []
    public var isLoading: Bool = false
    public var isLoadingDetail: Bool = false
    public var searchText: String = ""
    public var matchingTags: [RecipeTag] = []
    public var selectedCategory: RecipeCategory? = nil
    public var selectedTag: RecipeTag? = nil
    public var currentPage: Int = 1
    public var totalPages: Int = 1
    public var errorMessage: String = ""
    public var errorDetail: String = ""

    // Import
    public var importURL: String = ""
    public var isImporting: Bool = false
    public var importMessage: String = ""

    // Local mode
    public var isLocalMode: Bool = false

    // Duplicate detection
    public var duplicateRecipe: Recipe? = nil
    public var showDuplicateAlert: Bool = false
    public var pendingImportRecipe: Recipe? = nil
    public var duplicateMatchedByURL: Bool = false

    // Offline
    public var offlineRecipeIds: Set<String> = []
    public var isSavingOffline: Bool = false

    // Search debounce
    private var searchTask: Task<Void, Never>? = nil

    private let localStore: LocalRecipeStore

    private let importQueue: SharedImportQueue?
    private let parseRecipe: (String) async throws -> Recipe
    private let offlineStore: OfflineRecipeStore
    private let api: MealieAPI
    private let syncService: RecipeSyncService

    public init() { localStore = .shared; api = .shared; syncService = .shared; offlineStore = .shared; importQueue = .shared; parseRecipe = { try await RecipeURLParser.shared.parseRecipe(from: $0) } }
    init(localStore: LocalRecipeStore, api: MealieAPI = .shared, syncService: RecipeSyncService = .shared, offlineStore: OfflineRecipeStore = .shared,
         importQueue: SharedImportQueue? = .shared,
         parseRecipe: @escaping (String) async throws -> Recipe = { try await RecipeURLParser.shared.parseRecipe(from: $0) }) {
        self.localStore = localStore; self.api = api; self.syncService = syncService; self.offlineStore = offlineStore; self.importQueue = importQueue; self.parseRecipe = parseRecipe
    }

    public func refreshRecipes() async {
        guard !isLocalMode else { await loadRecipes(reset: true); return }
        let success = await syncService.syncAll()
        await loadRecipes(reset: true)
        errorMessage = success ? "" : syncService.pendingRecipeCount > 0
            ? "Some recipes could not be downloaded. Retry Recipe Sync in Settings."
            : "Failed to refresh recipes. Showing saved recipes."
        errorDetail = ""
        if success, let slug = selectedRecipe?.slug {
            selectedRecipe = syncService.loadRecipeBySlug(slug: slug)
        }
    }

    private func reportStorageFailure(_ error: Error) {
        errorMessage = "Your recipe changes could not be saved. Please try again."
        errorDetail = error.localizedDescription
    }

    public func loadRecipes(reset: Bool = false) async {
        if isLocalMode {
            isLoading = true
            if let storageError = localStore.initializationError {
                errorMessage = "Your recipe library could not be opened. Your saved data has been preserved."
                errorDetail = storageError
                isLoading = false
                return
            }
            let allRecipes = localStore.loadAllRecipes()
            var filtered = allRecipes

            // Filter by search (name, description, ingredients)
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                filtered = filtered.filter { recipe in
                    if (recipe.name ?? "").lowercased().contains(query) { return true }
                    if (recipe.description ?? "").lowercased().contains(query) { return true }
                    if let ingredients = recipe.recipeIngredient {
                        for ingredient in ingredients {
                            if let display = ingredient.display, display.lowercased().contains(query) { return true }
                            if let food = ingredient.food?.name, food.lowercased().contains(query) { return true }
                            if let note = ingredient.note, note.lowercased().contains(query) { return true }
                            if let original = ingredient.originalText, original.lowercased().contains(query) { return true }
                        }
                    }
                    return false
                }
            }
            // Filter by category
            if let cat = selectedCategory {
                filtered = filtered.filter { ($0.recipeCategory ?? []).contains(where: { $0.slug == cat.slug }) }
            }
            // Filter by tag
            if let tag = selectedTag {
                filtered = filtered.filter { ($0.tags ?? []).contains(where: { $0.slug == tag.slug }) }
            }
            recipes = filtered
                .sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
                .map { recipe in
                RecipeSummary(id: recipe.id, slug: localStore.navigationIdentifier(recipe), name: recipe.name,
                              description: recipe.description, image: recipe.image,
                              recipeCategory: recipe.recipeCategory, tags: recipe.tags,
                              rating: recipe.rating, dateAdded: recipe.dateAdded,
                              dateUpdated: recipe.dateUpdated)
            }
            totalPages = 1
            currentPage = 1
            isLoading = false
            return
        }

        // Server mode with sync available — read from sync store
        if syncService.isSynced {
            isLoading = true

            if !searchText.isEmpty {
                // Search full recipes locally for ingredient matching
                let allRecipes = syncService.loadAllSyncedRecipes()
                let query = searchText.lowercased()
                var filtered = allRecipes.filter { recipe in
                    if (recipe.name ?? "").lowercased().contains(query) { return true }
                    if (recipe.description ?? "").lowercased().contains(query) { return true }
                    if let ingredients = recipe.recipeIngredient {
                        for ingredient in ingredients {
                            if let display = ingredient.display, display.lowercased().contains(query) { return true }
                            if let food = ingredient.food?.name, food.lowercased().contains(query) { return true }
                            if let note = ingredient.note, note.lowercased().contains(query) { return true }
                            if let original = ingredient.originalText, original.lowercased().contains(query) { return true }
                        }
                    }
                    return false
                }
                if let cat = selectedCategory {
                    filtered = filtered.filter { ($0.recipeCategory ?? []).contains(where: { $0.slug == cat.slug }) }
                }
                if let tag = selectedTag {
                    filtered = filtered.filter { ($0.tags ?? []).contains(where: { $0.slug == tag.slug }) }
                }
                recipes = filtered
                    .sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
                    .map { recipe in
                    RecipeSummary(id: recipe.id, slug: recipe.slug, name: recipe.name,
                                  description: recipe.description, image: recipe.image,
                                  recipeCategory: recipe.recipeCategory, tags: recipe.tags,
                                  rating: recipe.rating, dateAdded: recipe.dateAdded,
                                  dateUpdated: recipe.dateUpdated)
                }
            } else {
                // Browse from summary index
                var all = syncService.loadSummaryIndex()
                if let cat = selectedCategory {
                    all = all.filter { ($0.recipeCategory ?? []).contains(where: { $0.slug == cat.slug }) }
                }
                if let tag = selectedTag {
                    all = all.filter { ($0.tags ?? []).contains(where: { $0.slug == tag.slug }) }
                }
                recipes = all
            }
            totalPages = 1
            currentPage = 1
            isLoading = false

            // Preload thumbnails in background
            let recipesToCache = recipes
            Task.detached {
                await ImageCacheService.shared.preloadThumbnails(recipes: recipesToCache)
            }
            return
        }

        // Fallback: not yet synced — use API directly
        if reset {
            currentPage = 1
        }

        isLoading = true
        errorMessage = ""
        errorDetail = ""

        do {
            let response = try await api.getRecipes(
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

            // Preload thumbnails in background
            let recipesToCache = recipes
            Task.detached {
                await ImageCacheService.shared.preloadThumbnails(recipes: recipesToCache)
            }
        } catch {
            errorMessage = "Failed to load recipes."
            errorDetail = AppEnvironment.errorDetail(error)
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
            selectedRecipe = localStore.loadRecipe(slug: slug)
            isLoadingDetail = false
            return
        }

        selectedRecipe = nil
        errorMessage = ""
        errorDetail = ""
        // Read from sync store if available
        if let synced = syncService.loadRecipeBySlug(slug: slug) {
            selectedRecipe = synced
            isLoadingDetail = false
            return
        }

        // Fallback: fetch from API (recipe may be brand new or sync incomplete)
        isLoadingDetail = true
        do {
            let recipe = try await api.getRecipe(slug: slug)
            selectedRecipe = recipe
            syncService.updateRecipe(recipe)
            isLoadingDetail = false
        } catch {
            if let saved = offlineStore.loadRecipeBySlug(slug: slug) {
                selectedRecipe = saved
                errorMessage = "Showing the saved offline copy."
            } else {
                errorMessage = "Failed to load recipe."
            }
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to load recipe detail: \(error)")
            isLoadingDetail = false
        }
    }

    public func loadCategories() async {
        if isLocalMode {
            var seen = Set<String>()
            var result: [RecipeCategory] = []
            for recipe in localStore.loadAllRecipes() {
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
            let response = try await api.getCategories()
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
            for recipe in localStore.loadAllRecipes() {
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
            let response = try await api.getTags()
            tags = response.items
            CacheService.shared.saveTags(response.items)
        } catch {
            logger.error("Failed to load tags: \(error)")
        }
    }

    public func deleteRecipe(slug: String) async -> Bool {
        if isLocalMode {
            do {
                if let recipe = localStore.loadRecipe(slug: slug), let id = recipe.id {
                    try localStore.deleteRecipe(id: id)
                }
                selectedRecipe = nil
                await loadRecipes(reset: true)
                return true
            } catch { reportStorageFailure(error); return false }
        }

        do {
            try await api.deleteRecipe(slug: slug)
            selectedRecipe = nil
            recipes.removeAll { $0.slug == slug }
            syncService.removeRecipe(slug: slug)
            return true
        } catch {
            errorMessage = "Failed to delete recipe."
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to delete recipe: \(error)")
            return false
        }
    }

    public var hasPendingSharedImports = false
    private var drainingShares = false
    private var queuedDuplicateURL: String?

    public func processPendingImports() async {
        guard let queue = importQueue, !drainingShares, !isImporting, pendingImportRecipe == nil else { return }
        drainingShares = true
        hasPendingSharedImports = !queue.pendingURLs().isEmpty
        defer {
            drainingShares = false
            hasPendingSharedImports = !queue.pendingURLs().isEmpty
        }
        while let url = queue.pendingURLs().first {
            importURL = url
            let saved = await importFromURL()
            if pendingImportRecipe != nil {
                queuedDuplicateURL = url
                break
            }
            guard saved else {
                errorMessage = "A shared link could not be imported. Retry Shared Imports to try again."
                break
            }
            queue.remove(url)
        }
    }

    @discardableResult
    public func importFromURL() async -> Bool {
        guard !importURL.isEmpty, !isImporting, pendingImportRecipe == nil else { return false }
        isImporting = true
        importMessage = ""

        if isLocalMode {
            do {
                let recipe = try await parseRecipe(importURL)

                // Check for duplicates
                if let existing = localStore.findRecipeByOrgURL(importURL) {
                    duplicateRecipe = existing
                    pendingImportRecipe = recipe
                    duplicateMatchedByURL = true
                    showDuplicateAlert = true
                    isImporting = false
                    return true
                }
                if let name = recipe.name, let existing = localStore.findRecipesByName(name).first {
                    duplicateRecipe = existing
                    pendingImportRecipe = recipe
                    duplicateMatchedByURL = false
                    showDuplicateAlert = true
                    isImporting = false
                    return true
                }

                try localStore.saveRecipe(recipe)
                importMessage = "Recipe imported successfully!"
                importURL = ""
                isImporting = false
                await loadRecipes(reset: true)
                return true
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
                return false
            } catch {
                importMessage = "Failed to import recipe."
                logger.error("Local import error: \(error)")
                isImporting = false
                return false
            }
        }

        do {
            let slug = try await api.createRecipeFromURL(url: importURL)
            importURL = ""
            isImporting = false
            let landed = await ingestImportedRecipe(slug: slug)
            importMessage = landed
                ? "Recipe imported successfully!"
                : "Recipe imported — the server is still processing it."
            return true
        } catch {
            importMessage = "Failed to import recipe. Check the URL."
            logger.error("Failed to import recipe: \(error)")
            isImporting = false
            return false
        }
    }

    /// Pulls a recipe the server has just created into the sync store and
    /// refreshes the list.
    ///
    /// In synced server mode `loadRecipes` reads the sync store, so a brand new
    /// recipe is invisible until it is written there. Mealie can still be
    /// scraping the page when the create call returns, so this retries the
    /// fetch for a few seconds before giving up.
    ///
    /// Returns whether the recipe was actually fetched. The list is refreshed
    /// either way, so a slow import still shows up on the next refresh or sync.
    @discardableResult
    public func ingestImportedRecipe(slug: String) async -> Bool {
        var fetched: Recipe? = nil
        for delayMs in [400, 800, 1_500, 2_500] {
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            if let recipe = try? await api.getRecipe(slug: slug) {
                fetched = recipe
                break
            }
        }
        if let recipe = fetched {
            syncService.updateRecipe(recipe)
        } else {
            logger.error("Imported recipe \(slug) was not readable back from the server yet")
        }
        await loadRecipes(reset: true)
        return fetched != nil
    }

    @discardableResult public func confirmImportNew() async -> Bool {
        guard let recipe = pendingImportRecipe else { return false }
        do { try localStore.saveRecipe(recipe) }
        catch { reportStorageFailure(error); importMessage = errorMessage; showDuplicateAlert = true; return false }
        importMessage = "Recipe imported successfully!"
        importURL = ""
        clearDuplicateState()
        await loadRecipes(reset: true)
        return true
    }

    @discardableResult public func confirmImportUpdate() async -> Bool {
        guard let pending = pendingImportRecipe, let existing = duplicateRecipe else { return false }
        let now = ISO8601DateFormatter().string(from: Date())
        let updated = Recipe(
            id: existing.id, slug: existing.slug,
            name: pending.name, description: pending.description, image: pending.image,
            recipeCategory: pending.recipeCategory, tags: pending.tags, tools: pending.tools,
            rating: pending.rating, recipeYield: pending.recipeYield,
            recipeIngredient: pending.recipeIngredient, recipeInstructions: pending.recipeInstructions,
            totalTime: pending.totalTime, prepTime: pending.prepTime, performTime: pending.performTime,
            nutrition: pending.nutrition, settings: pending.settings,
            dateAdded: existing.dateAdded, dateUpdated: now,
            createdAt: existing.createdAt, updatedAt: now,
            orgURL: pending.orgURL, extras: pending.extras
        )
        do { try localStore.saveRecipe(updated) }
        catch { reportStorageFailure(error); importMessage = errorMessage; showDuplicateAlert = true; return false }
        importMessage = "Recipe updated successfully!"
        importURL = ""
        clearDuplicateState()
        await loadRecipes(reset: true)
        return true
    }

    public func clearDuplicateState() {
        if let queuedDuplicateURL { importQueue?.remove(queuedDuplicateURL) }
        hasPendingSharedImports = !(importQueue?.pendingURLs().isEmpty ?? true)
        queuedDuplicateURL = nil
        duplicateRecipe = nil
        pendingImportRecipe = nil
        showDuplicateAlert = false
        duplicateMatchedByURL = false
    }

    public func search() async {
        searchTask?.cancel()
        await loadRecipes(reset: true)
    }

    public func debouncedSearch() {
        searchTask?.cancel()

        if searchText.isEmpty {
            matchingTags = []
            Task { await loadRecipes(reset: true) }
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            let query = searchText.lowercased()
            matchingTags = tags.filter { ($0.name ?? "").lowercased().contains(query) }

            await loadRecipes(reset: true)
        }
    }

    // MARK: - Favorites

    public var favoriteRecipes: Set<String> = []

    public func loadFavorites(user: User?) {
        if isLocalMode {
            do { favoriteRecipes = try localStore.loadNavigationFavorites() }
            catch { reportStorageFailure(error) }
            return
        }
        guard let slugs = user?.favoriteRecipes else { return }
        favoriteRecipes = Set(slugs)
    }

    public func isFavorite(slug: String) -> Bool {
        favoriteRecipes.contains(slug)
    }

    public func toggleFavorite(slug: String, userId: String) async {
        let wasFavorite = favoriteRecipes.contains(slug)

        if isLocalMode {
            do {
                if wasFavorite {
                    try localStore.removeFavorite(slug: slug)
                    favoriteRecipes.remove(slug)
                } else {
                    try localStore.addFavorite(slug: slug)
                    favoriteRecipes.insert(slug)
                }
            } catch { reportStorageFailure(error) }
            return
        }

        // Optimistic update
        if wasFavorite {
            favoriteRecipes.remove(slug)
        } else {
            favoriteRecipes.insert(slug)
        }

        do {
            if wasFavorite {
                try await api.removeFavorite(userId: userId, slug: slug)
            } else {
                try await api.addFavorite(userId: userId, slug: slug)
            }
        } catch {
            // Revert on failure
            if wasFavorite {
                favoriteRecipes.insert(slug)
            } else {
                favoriteRecipes.remove(slug)
            }
            errorMessage = "Failed to update favorite."
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to toggle favorite: \(error)")
        }
    }

    // MARK: - Update Recipe

    public func updateRecipe(slug: String, data: Recipe) async -> Bool {
        if isLocalMode {
            do {
                try localStore.saveRecipe(data)
                selectedRecipe = localStore.loadRecipe(slug: localStore.navigationIdentifier(data) ?? slug) ?? data
                await loadRecipes(reset: true)
                return true
            } catch { reportStorageFailure(error); return false }
        }

        do {
            let updated = try await api.updateRecipe(slug: slug, data: data)
            selectedRecipe = updated
            syncService.updateRecipe(updated)
            await loadRecipes(reset: true)
            return true
        } catch {
            errorMessage = "Failed to update recipe."
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to update recipe: \(error)")
            return false
        }
    }

    // MARK: - Offline

    public func loadOfflineIds() {
        offlineRecipeIds = offlineStore.savedRecipeIds()
    }

    public func isOffline(recipeId: String) -> Bool {
        offlineRecipeIds.contains(recipeId)
    }

    public func saveRecipeOffline(slug: String) async {
        isSavingOffline = true
        do {
            let recipe = try await api.getRecipe(slug: slug)
            var imageData: Data? = nil
            if let recipeId = recipe.id {
                let urlString = api.recipeImageURL(recipeId: recipeId)
                if let url = URL(string: urlString) {
                    imageData = try? await URLSession.shared.data(from: url).0
                }
            }
            try offlineStore.saveRecipe(recipe, imageData: imageData)
            if let id = recipe.id {
                offlineRecipeIds.insert(id)
            }
            isSavingOffline = false
        } catch {
            errorMessage = "Could not save recipe offline. Please try again."
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to save recipe offline: \(error)")
            isSavingOffline = false
        }
    }

    public func removeRecipeOffline(recipeId: String) {
        offlineStore.removeRecipe(id: recipeId)
        offlineRecipeIds.remove(recipeId)
    }

    public func toggleOffline(slug: String, recipeId: String) async {
        if offlineRecipeIds.contains(recipeId) {
            removeRecipeOffline(recipeId: recipeId)
        } else {
            await saveRecipeOffline(slug: slug)
        }
    }

    public func saveRecipeEdits(slug: String, data: Recipe, imageData: Data?) async -> Bool {
        guard await updateRecipe(slug: slug, data: data) else { return false }
        if let imageData, !(await uploadImage(slug: selectedRecipe?.slug ?? slug, imageData: imageData)) {
            errorMessage = "Recipe saved, but the image could not be saved. Please try again."
            return false
        }
        errorMessage = ""
        errorDetail = ""
        return true
    }

    public var imageRevision = 0

    // MARK: - Image Upload

    public func uploadImage(slug: String, imageData: Data) async -> Bool {
        if isLocalMode {
            guard let recipe = selectedRecipe else { return false }
            do {
                try localStore.saveRecipeImage(imageData, recipe: recipe)
                selectedRecipe = localStore.loadRecipe(slug: localStore.navigationIdentifier(recipe) ?? slug)
                imageRevision += 1
                await loadRecipes(reset: true)
                return true
            } catch { reportStorageFailure(error); return false }
        }

        do {
            try await api.uploadRecipeImage(slug: slug, imageData: imageData)
            // Clear cached images so fresh ones are loaded
            if let recipeId = selectedRecipe?.id {
                ImageCacheService.shared.removeCachedImages(recipeId: recipeId)
                for size in ["tiny-original.webp", "min-original.webp", "original.webp"] {
                    if let url = URL(string: api.recipeImageURL(recipeId: recipeId, imageType: size)) {
                        URLCache.shared.removeCachedResponse(for: URLRequest(url: url))
                    }
                }
                try offlineStore.replaceImageIfSaved(id: recipeId, data: imageData)
                imageRevision += 1
            }
            return true
        } catch {
            errorMessage = "Failed to upload image."
            errorDetail = AppEnvironment.errorDetail(error)
            logger.error("Failed to upload recipe image: \(error)")
            return false
        }
    }

    public func makeLocalRecipeDraft(name: String) -> Recipe {
        let id = UUID().uuidString
        let slug = localStore.generateSlug(from: name)
        let now = ISO8601DateFormatter().string(from: Date())

        let recipe = Recipe(
            id: id, slug: slug, name: name, description: nil, image: nil,
            recipeCategory: nil, tags: nil, tools: nil, rating: nil,
            recipeYield: nil, recipeIngredient: nil, recipeInstructions: nil,
            totalTime: nil, prepTime: nil, performTime: nil, nutrition: nil,
            settings: nil, dateAdded: now, dateUpdated: now,
            createdAt: now, updatedAt: now, orgURL: nil, extras: nil
        )
        return recipe
    }

    public func createLocalRecipe(name: String) async -> Recipe? {
        let recipe = makeLocalRecipeDraft(name: name)
        do { try localStore.saveRecipe(recipe) }
        catch { reportStorageFailure(error); importMessage = errorMessage; return nil }
        await loadRecipes(reset: true)
        return recipe
    }
}
