package com.jackabee.mealie.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.jackabee.mealie.data.api.MealieApiSource
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipeCategory
import com.jackabee.mealie.data.model.RecipeSummary
import com.jackabee.mealie.data.model.RecipeTag
import com.jackabee.mealie.data.model.User
import com.jackabee.mealie.data.parser.RecipeParseException
import com.jackabee.mealie.data.parser.RecipeParser
import com.jackabee.mealie.data.store.CacheService
import com.jackabee.mealie.data.store.LocalRecipeStore
import com.jackabee.mealie.data.store.OfflineRecipeStore
import com.jackabee.mealie.data.store.RecipeSyncService
import com.jackabee.mealie.di.AppContainer
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

private const val TAG = "RecipeViewModel"

/** UI state for the recipes feature. Port of the Swift RecipeViewModel's observable properties. */
data class RecipeUiState(
    val recipes: List<RecipeSummary> = emptyList(),
    val selectedRecipe: Recipe? = null,
    val categories: List<RecipeCategory> = emptyList(),
    val tags: List<RecipeTag> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingDetail: Boolean = false,
    val searchText: String = "",
    val matchingTags: List<RecipeTag> = emptyList(),
    val selectedCategory: RecipeCategory? = null,
    val selectedTag: RecipeTag? = null,
    val currentPage: Int = 1,
    val totalPages: Int = 1,
    val errorMessage: String = "",
    val errorDetail: String = "",
    // Import
    val importURL: String = "",
    val isImporting: Boolean = false,
    val importMessage: String = "",
    // Local mode
    val isLocalMode: Boolean = false,
    // Duplicate detection
    val duplicateRecipe: Recipe? = null,
    val showDuplicateAlert: Boolean = false,
    val pendingImportRecipe: Recipe? = null,
    val duplicateMatchedByURL: Boolean = false,
    // Offline
    val offlineRecipeIds: Set<String> = emptySet(),
    val isSavingOffline: Boolean = false,
    // Favorites
    val favoriteRecipes: Set<String> = emptySet(),
)

/** Port of ios/Sources/MealieModel/ViewModels/RecipeViewModel.swift. */
class RecipeViewModel(
    private val api: MealieApiSource,
    private val localStore: LocalRecipeStore,
    private val syncService: RecipeSyncService,
    private val offlineStore: OfflineRecipeStore,
    private val cache: CacheService,
    private val parser: RecipeParser,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : ViewModel() {

    private val _uiState = MutableStateFlow(RecipeUiState())
    val uiState: StateFlow<RecipeUiState> = _uiState.asStateFlow()

    /** Search debounce, mirroring the Swift `searchTask`. */
    private var searchJob: Job? = null

    // MARK: State setters (two-way bindings in Swift)

    fun setLocalMode(isLocalMode: Boolean) = _uiState.update { it.copy(isLocalMode = isLocalMode) }

    fun updateImportURL(value: String) = _uiState.update { it.copy(importURL = value) }

    fun selectCategory(category: RecipeCategory?) = _uiState.update { it.copy(selectedCategory = category) }

    fun selectTag(tag: RecipeTag?) = _uiState.update { it.copy(selectedTag = tag) }

    /** Mirrors the Swift searchText binding + `.onChange { debouncedSearch() }`. */
    fun updateSearchText(value: String) {
        _uiState.update { it.copy(searchText = value) }
        debouncedSearch()
    }

    // MARK: Loading

    suspend fun loadRecipes(reset: Boolean = false) {
        val state = _uiState.value

        if (state.isLocalMode) {
            _uiState.update { it.copy(isLoading = true) }
            val allRecipes = withContext(ioDispatcher) { localStore.loadAllRecipes() }
            val summaries = filterAndSort(allRecipes, state).map { it.toSummary() }
            _uiState.update {
                it.copy(recipes = summaries, totalPages = 1, currentPage = 1, isLoading = false)
            }
            return
        }

        // Server mode with sync available — read from sync store
        if (withContext(ioDispatcher) { syncService.isSynced }) {
            _uiState.update { it.copy(isLoading = true) }

            val recipes: List<RecipeSummary> = if (state.searchText.isNotEmpty()) {
                // Search full recipes locally for ingredient matching
                val allRecipes = withContext(ioDispatcher) { syncService.loadAllSyncedRecipes() }
                filterAndSort(allRecipes, state).map { it.toSummary() }
            } else {
                // Browse from summary index
                var all = withContext(ioDispatcher) { syncService.loadSummaryIndex() }
                state.selectedCategory?.let { cat ->
                    all = all.filter { r -> r.recipeCategory.orEmpty().any { it.slug == cat.slug } }
                }
                state.selectedTag?.let { tag ->
                    all = all.filter { r -> r.tags.orEmpty().any { it.slug == tag.slug } }
                }
                all
            }
            _uiState.update {
                it.copy(recipes = recipes, totalPages = 1, currentPage = 1, isLoading = false)
            }
            return
        }

        // Fallback: not yet synced — use API directly
        if (reset) {
            _uiState.update { it.copy(currentPage = 1) }
        }

        _uiState.update { it.copy(isLoading = true, errorMessage = "", errorDetail = "") }

        try {
            val page = _uiState.value.currentPage
            val response = withContext(ioDispatcher) {
                api.getRecipes(
                    page = page,
                    perPage = 30,
                    search = state.searchText.takeIf { it.isNotEmpty() },
                    categories = state.selectedCategory?.id?.let { listOf(it) },
                    tags = state.selectedTag?.id?.let { listOf(it) },
                )
            }
            _uiState.update {
                it.copy(
                    recipes = if (reset) response.items else it.recipes + response.items,
                    totalPages = response.totalPages,
                    isLoading = false,
                )
            }
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to load recipes: $e", e)
            _uiState.update {
                it.copy(errorMessage = "Failed to load recipes.", errorDetail = errorDetail(e), isLoading = false)
            }
        }
    }

    suspend fun loadNextPage() {
        val state = _uiState.value
        if (state.currentPage >= state.totalPages || state.isLoading) return
        _uiState.update { it.copy(currentPage = it.currentPage + 1) }
        loadRecipes()
    }

    suspend fun loadRecipeDetail(slug: String) {
        if (_uiState.value.isLocalMode) {
            val recipe = withContext(ioDispatcher) { localStore.loadRecipe(slug) }
            _uiState.update { it.copy(selectedRecipe = recipe, isLoadingDetail = false) }
            return
        }

        // Read from sync store if available
        val synced = withContext(ioDispatcher) { syncService.loadRecipeBySlug(slug) }
        if (synced != null) {
            _uiState.update { it.copy(selectedRecipe = synced, isLoadingDetail = false) }
            return
        }

        // Fallback: fetch from API (recipe may be brand new or sync incomplete)
        _uiState.update { it.copy(isLoadingDetail = true) }
        try {
            val recipe = withContext(ioDispatcher) { api.getRecipe(slug) }
            withContext(ioDispatcher) { syncService.updateRecipe(recipe) }
            _uiState.update { it.copy(selectedRecipe = recipe, isLoadingDetail = false) }
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to load recipe detail: $e", e)
            _uiState.update {
                it.copy(errorMessage = "Failed to load recipe.", errorDetail = errorDetail(e), isLoadingDetail = false)
            }
        }
    }

    suspend fun loadCategories() {
        if (_uiState.value.isLocalMode) {
            val result = withContext(ioDispatcher) {
                distinctBySlug(localStore.loadAllRecipes().flatMap { it.recipeCategory.orEmpty() }) { it.slug }
            }
            _uiState.update { it.copy(categories = result) }
            return
        }

        if (_uiState.value.categories.isEmpty()) {
            withContext(ioDispatcher) { cache.loadCategories() }?.let { cached ->
                _uiState.update { it.copy(categories = cached) }
            }
        }
        try {
            val response = withContext(ioDispatcher) { api.getCategories() }
            withContext(ioDispatcher) { cache.saveCategories(response.items) }
            _uiState.update { it.copy(categories = response.items) }
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to load categories: $e", e)
        }
    }

    suspend fun loadTags() {
        if (_uiState.value.isLocalMode) {
            val result = withContext(ioDispatcher) {
                distinctBySlug(localStore.loadAllRecipes().flatMap { it.tags.orEmpty() }) { it.slug }
            }
            _uiState.update { it.copy(tags = result) }
            return
        }

        if (_uiState.value.tags.isEmpty()) {
            withContext(ioDispatcher) { cache.loadTags() }?.let { cached ->
                _uiState.update { it.copy(tags = cached) }
            }
        }
        try {
            val response = withContext(ioDispatcher) { api.getTags() }
            withContext(ioDispatcher) { cache.saveTags(response.items) }
            _uiState.update { it.copy(tags = response.items) }
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to load tags: $e", e)
        }
    }

    // MARK: Delete

    suspend fun deleteRecipe(slug: String): Boolean {
        if (_uiState.value.isLocalMode) {
            withContext(ioDispatcher) {
                localStore.loadRecipe(slug)?.id?.let { localStore.deleteRecipe(it) }
            }
            _uiState.update { it.copy(selectedRecipe = null) }
            loadRecipes(reset = true)
            return true
        }

        return try {
            withContext(ioDispatcher) { api.deleteRecipe(slug) }
            withContext(ioDispatcher) { syncService.removeRecipe(slug) }
            _uiState.update { state ->
                state.copy(selectedRecipe = null, recipes = state.recipes.filterNot { it.slug == slug })
            }
            true
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to delete recipe: $e", e)
            _uiState.update {
                it.copy(errorMessage = "Failed to delete recipe.", errorDetail = errorDetail(e))
            }
            false
        }
    }

    // MARK: Import

    suspend fun importFromURL(): Boolean {
        val importURL = _uiState.value.importURL
        if (importURL.isEmpty()) return false
        _uiState.update { it.copy(isImporting = true, importMessage = "") }

        if (_uiState.value.isLocalMode) {
            return try {
                val recipe = parser.parseRecipe(importURL)

                // Check for duplicates
                val existingByURL = withContext(ioDispatcher) { localStore.findRecipeByOrgURL(importURL) }
                if (existingByURL != null) {
                    _uiState.update {
                        it.copy(
                            duplicateRecipe = existingByURL,
                            pendingImportRecipe = recipe,
                            duplicateMatchedByURL = true,
                            showDuplicateAlert = true,
                            isImporting = false,
                        )
                    }
                    return true
                }
                val existingByName = recipe.name?.let { name ->
                    withContext(ioDispatcher) { localStore.findRecipesByName(name) }.firstOrNull()
                }
                if (existingByName != null) {
                    _uiState.update {
                        it.copy(
                            duplicateRecipe = existingByName,
                            pendingImportRecipe = recipe,
                            duplicateMatchedByURL = false,
                            showDuplicateAlert = true,
                            isImporting = false,
                        )
                    }
                    return true
                }

                withContext(ioDispatcher) { localStore.saveRecipe(recipe) }
                _uiState.update {
                    it.copy(importMessage = "Recipe imported successfully!", importURL = "", isImporting = false)
                }
                loadRecipes(reset = true)
                true
            } catch (e: RecipeParseException) {
                AppLog.w(TAG, "Local import error: $e", e)
                val message = when (e) {
                    is RecipeParseException.InvalidUrl -> "Invalid URL."
                    is RecipeParseException.FetchFailed -> "Could not fetch page: ${e.detail}"
                    is RecipeParseException.NoRecipeFound -> "No recipe found on that page."
                    is RecipeParseException.ParsingFailed -> "Failed to parse recipe: ${e.detail}"
                }
                _uiState.update { it.copy(importMessage = message, isImporting = false) }
                false
            } catch (e: Exception) {
                AppLog.w(TAG, "Local import error: $e", e)
                _uiState.update { it.copy(importMessage = "Failed to import recipe.", isImporting = false) }
                false
            }
        }

        return try {
            val slug = withContext(ioDispatcher) { api.createRecipeFromURL(importURL) }
            _uiState.update { it.copy(importURL = "", isImporting = false) }
            val landed = ingestImportedRecipe(slug)
            _uiState.update {
                it.copy(
                    importMessage = if (landed) {
                        "Recipe imported successfully!"
                    } else {
                        "Recipe imported — the server is still processing it."
                    },
                )
            }
            true
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to import recipe: $e", e)
            _uiState.update { it.copy(importMessage = "Failed to import recipe. Check the URL.", isImporting = false) }
            false
        }
    }

    /**
     * Pulls a recipe the server has just created into the sync store and
     * refreshes the list.
     *
     * In synced server mode [loadRecipes] reads the sync store, so a brand new
     * recipe stays invisible until it is written there. Mealie can still be
     * scraping the page when the create call returns, so the fetch is retried
     * for a few seconds before giving up.
     *
     * Returns whether the recipe was actually fetched. The list is refreshed
     * either way, so a slow import still appears on the next refresh or sync.
     */
    suspend fun ingestImportedRecipe(slug: String): Boolean {
        var fetched: Recipe? = null
        for (delayMs in listOf(400L, 800L, 1500L, 2500L)) {
            delay(delayMs)
            fetched = try {
                withContext(ioDispatcher) { api.getRecipe(slug) }
            } catch (_: Exception) {
                null
            }
            if (fetched != null) break
        }
        val recipe = fetched
        if (recipe != null) {
            withContext(ioDispatcher) { syncService.updateRecipe(recipe) }
        } else {
            AppLog.w(TAG, "Imported recipe $slug was not readable back from the server yet")
        }
        loadRecipes(reset = true)
        return recipe != null
    }

    suspend fun confirmImportNew() {
        val recipe = _uiState.value.pendingImportRecipe ?: return
        withContext(ioDispatcher) { localStore.saveRecipe(recipe) }
        _uiState.update { it.copy(importMessage = "Recipe imported successfully!", importURL = "") }
        clearDuplicateState()
        loadRecipes(reset = true)
    }

    suspend fun confirmImportUpdate() {
        val state = _uiState.value
        val pending = state.pendingImportRecipe ?: return
        val existing = state.duplicateRecipe ?: return
        val now = isoNow()
        val updated = pending.copy(
            id = existing.id,
            slug = existing.slug,
            dateAdded = existing.dateAdded,
            dateUpdated = now,
            createdAt = existing.createdAt,
            updatedAt = now,
        )
        withContext(ioDispatcher) { localStore.saveRecipe(updated) }
        _uiState.update { it.copy(importMessage = "Recipe updated successfully!", importURL = "") }
        clearDuplicateState()
        loadRecipes(reset = true)
    }

    fun clearDuplicateState() = _uiState.update {
        it.copy(
            duplicateRecipe = null,
            pendingImportRecipe = null,
            showDuplicateAlert = false,
            duplicateMatchedByURL = false,
        )
    }

    // MARK: Search

    suspend fun search() {
        searchJob?.cancel()
        loadRecipes(reset = true)
    }

    fun debouncedSearch() {
        searchJob?.cancel()

        if (_uiState.value.searchText.isEmpty()) {
            _uiState.update { it.copy(matchingTags = emptyList()) }
            searchJob = viewModelScope.launch { loadRecipes(reset = true) }
            return
        }

        searchJob = viewModelScope.launch {
            delay(300)

            val query = _uiState.value.searchText.lowercase()
            _uiState.update { state ->
                state.copy(matchingTags = state.tags.filter { it.name?.lowercase()?.contains(query) == true })
            }

            loadRecipes(reset = true)
        }
    }

    // MARK: Favorites

    fun loadFavorites(user: User?) {
        if (_uiState.value.isLocalMode) {
            _uiState.update { it.copy(favoriteRecipes = localStore.loadFavorites()) }
            return
        }
        val slugs = user?.favoriteRecipes ?: return
        _uiState.update { it.copy(favoriteRecipes = slugs.toSet()) }
    }

    fun isFavorite(slug: String): Boolean = _uiState.value.favoriteRecipes.contains(slug)

    suspend fun toggleFavorite(slug: String, userId: String) {
        val wasFavorite = _uiState.value.favoriteRecipes.contains(slug)

        if (_uiState.value.isLocalMode) {
            if (wasFavorite) {
                _uiState.update { it.copy(favoriteRecipes = it.favoriteRecipes - slug) }
                withContext(ioDispatcher) { localStore.removeFavorite(slug) }
            } else {
                _uiState.update { it.copy(favoriteRecipes = it.favoriteRecipes + slug) }
                withContext(ioDispatcher) { localStore.addFavorite(slug) }
            }
            return
        }

        // Optimistic update
        _uiState.update {
            it.copy(favoriteRecipes = if (wasFavorite) it.favoriteRecipes - slug else it.favoriteRecipes + slug)
        }

        try {
            withContext(ioDispatcher) {
                if (wasFavorite) api.removeFavorite(userId, slug) else api.addFavorite(userId, slug)
            }
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to toggle favorite: $e", e)
            // Revert on failure
            _uiState.update {
                it.copy(
                    favoriteRecipes = if (wasFavorite) it.favoriteRecipes + slug else it.favoriteRecipes - slug,
                    errorMessage = "Failed to update favorite.",
                    errorDetail = errorDetail(e),
                )
            }
        }
    }

    // MARK: Update Recipe

    suspend fun updateRecipe(slug: String, data: Recipe): Boolean {
        if (_uiState.value.isLocalMode) {
            withContext(ioDispatcher) { localStore.saveRecipe(data) }
            _uiState.update { it.copy(selectedRecipe = data) }
            loadRecipes(reset = true)
            return true
        }

        return try {
            val updated = withContext(ioDispatcher) { api.updateRecipe(slug, data) }
            withContext(ioDispatcher) { syncService.updateRecipe(updated) }
            _uiState.update { it.copy(selectedRecipe = updated) }
            loadRecipes(reset = true)
            true
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to update recipe: $e", e)
            _uiState.update {
                it.copy(errorMessage = "Failed to update recipe.", errorDetail = errorDetail(e))
            }
            false
        }
    }

    // MARK: Offline

    fun loadOfflineIds() = _uiState.update { it.copy(offlineRecipeIds = offlineStore.savedRecipeIds()) }

    fun isOffline(recipeId: String): Boolean = _uiState.value.offlineRecipeIds.contains(recipeId)

    suspend fun saveRecipeOffline(slug: String) {
        _uiState.update { it.copy(isSavingOffline = true) }
        try {
            val recipe = withContext(ioDispatcher) { api.getRecipe(slug) }
            val imageData = recipe.id?.let { id -> api.downloadRecipeImage(id) }
            withContext(ioDispatcher) { offlineStore.saveRecipe(recipe, imageData) }
            _uiState.update { state ->
                state.copy(
                    offlineRecipeIds = recipe.id?.let { state.offlineRecipeIds + it } ?: state.offlineRecipeIds,
                    isSavingOffline = false,
                )
            }
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to save recipe offline: $e", e)
            _uiState.update { it.copy(isSavingOffline = false) }
        }
    }

    fun removeRecipeOffline(recipeId: String) {
        offlineStore.removeRecipe(recipeId)
        _uiState.update { it.copy(offlineRecipeIds = it.offlineRecipeIds - recipeId) }
    }

    suspend fun toggleOffline(slug: String, recipeId: String) {
        if (_uiState.value.offlineRecipeIds.contains(recipeId)) {
            removeRecipeOffline(recipeId)
        } else {
            saveRecipeOffline(slug)
        }
    }

    // MARK: Image Upload

    suspend fun uploadImage(slug: String, imageData: ByteArray): Boolean {
        if (_uiState.value.isLocalMode) {
            _uiState.value.selectedRecipe?.id?.let { id ->
                withContext(ioDispatcher) { localStore.saveImage(imageData, id) }
            }
            return true
        }

        return try {
            withContext(ioDispatcher) { api.uploadRecipeImage(slug, imageData) }
            // Note: on iOS the ImageCacheService is invalidated here; on Android
            // image caching is handled by Coil, keyed by URL.
            true
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to upload recipe image: $e", e)
            _uiState.update {
                it.copy(errorMessage = "Failed to upload image.", errorDetail = errorDetail(e))
            }
            false
        }
    }

    // MARK: Local create

    suspend fun createLocalRecipe(name: String): Recipe {
        val now = isoNow()
        val recipe = Recipe(
            id = UUID.randomUUID().toString(),
            slug = LocalRecipeStore.generateSlug(name),
            name = name,
            dateAdded = now,
            dateUpdated = now,
            createdAt = now,
            updatedAt = now,
        )
        withContext(ioDispatcher) { localStore.saveRecipe(recipe) }
        loadRecipes(reset = true)
        return recipe
    }

    // MARK: Private helpers

    /** Mirrors Swift ISO8601DateFormatter().string(from: Date()). */
    private fun isoNow(): String = Instant.now().truncatedTo(ChronoUnit.SECONDS).toString()

    private fun filterAndSort(recipes: List<Recipe>, state: RecipeUiState): List<Recipe> {
        var filtered = recipes

        // Filter by search (name, description, ingredients)
        if (state.searchText.isNotEmpty()) {
            val query = state.searchText.lowercase()
            filtered = filtered.filter { it.matchesQuery(query) }
        }
        // Filter by category
        state.selectedCategory?.let { cat ->
            filtered = filtered.filter { r -> r.recipeCategory.orEmpty().any { it.slug == cat.slug } }
        }
        // Filter by tag
        state.selectedTag?.let { tag ->
            filtered = filtered.filter { r -> r.tags.orEmpty().any { it.slug == tag.slug } }
        }
        return filtered.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.name ?: "" })
    }

    private fun Recipe.matchesQuery(query: String): Boolean {
        if (name?.lowercase()?.contains(query) == true) return true
        if (description?.lowercase()?.contains(query) == true) return true
        for (ingredient in recipeIngredient.orEmpty()) {
            if (ingredient.display?.lowercase()?.contains(query) == true) return true
            if (ingredient.food?.name?.lowercase()?.contains(query) == true) return true
            if (ingredient.note?.lowercase()?.contains(query) == true) return true
            if (ingredient.originalText?.lowercase()?.contains(query) == true) return true
        }
        return false
    }

    private fun Recipe.toSummary() = RecipeSummary(
        id = id, slug = slug, name = name,
        description = description, image = image,
        recipeCategory = recipeCategory, tags = tags,
        rating = rating, dateAdded = dateAdded,
        dateUpdated = dateUpdated,
    )

    private fun <T> distinctBySlug(items: List<T>, slugOf: (T) -> String?): List<T> {
        val seen = mutableSetOf<String>()
        val result = mutableListOf<T>()
        for (item in items) {
            val slug = slugOf(item) ?: continue
            if (seen.add(slug)) result.add(item)
        }
        return result
    }

    companion object {
        fun factory(container: AppContainer): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                RecipeViewModel(
                    api = container.api,
                    localStore = container.localRecipeStore,
                    syncService = container.recipeSyncService,
                    offlineStore = container.offlineRecipeStore,
                    cache = container.cache,
                    parser = container.recipeUrlParser,
                )
            }
        }
    }
}
