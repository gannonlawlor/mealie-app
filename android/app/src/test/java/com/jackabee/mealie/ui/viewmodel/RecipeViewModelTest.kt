package com.jackabee.mealie.ui.viewmodel

import com.jackabee.mealie.FakeKeyValueStore
import com.jackabee.mealie.data.api.MealieApi
import com.jackabee.mealie.data.api.MealieClient
import com.jackabee.mealie.data.model.IngredientFood
import com.jackabee.mealie.data.model.MealieJson
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipeCategory
import com.jackabee.mealie.data.model.RecipeIngredient
import com.jackabee.mealie.data.model.RecipePaginatedResponse
import com.jackabee.mealie.data.model.RecipeSummary
import com.jackabee.mealie.data.model.RecipeTag
import com.jackabee.mealie.data.model.User
import com.jackabee.mealie.data.parser.RecipeParseException
import com.jackabee.mealie.data.store.CacheService
import com.jackabee.mealie.data.store.LocalRecipeStore
import com.jackabee.mealie.data.store.OfflineRecipeStore
import com.jackabee.mealie.data.store.RecipeSyncService
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class RecipeViewModelTest {

    @get:Rule
    val mainRule = MainDispatcherRule()

    @get:Rule
    val tmp = TemporaryFolder()

    private class Env(root: File, rule: MainDispatcherRule) {
        val kv = FakeKeyValueStore()
        val dao = FakeLocalRecipeDao()
        val api = FakeMealieApiSource()
        val localStore = LocalRecipeStore(dao, kv, MealieJson, File(root, "files"))
        val syncService = RecipeSyncService(File(root, "files"), kv, MealieApi(MealieClient(), MealieJson), MealieJson)
        val offlineStore = OfflineRecipeStore(File(root, "files"), kv, MealieJson)
        val cache = CacheService(File(root, "cache"), MealieJson)
        val parser = FakeRecipeParser()
        val vm = RecipeViewModel(api, localStore, syncService, offlineStore, cache, parser, rule.dispatcher)
    }

    private fun env() = Env(tmp.root, mainRule)

    private fun recipe(
        id: String,
        name: String,
        description: String? = null,
        ingredients: List<RecipeIngredient>? = null,
        categories: List<RecipeCategory>? = null,
        tags: List<RecipeTag>? = null,
        orgURL: String? = null,
        dateAdded: String? = null,
    ) = Recipe(
        id = id,
        slug = name.lowercase().replace(" ", "-"),
        name = name,
        description = description,
        recipeIngredient = ingredients,
        recipeCategory = categories,
        tags = tags,
        orgURL = orgURL,
        dateAdded = dateAdded,
    )

    private suspend fun seedPantry(env: Env) {
        env.localStore.saveRecipe(
            recipe(
                "1", "Pasta Carbonara",
                ingredients = listOf(RecipeIngredient(note = "guanciale"), RecipeIngredient(display = "3 eggs")),
                tags = listOf(RecipeTag(id = "t1", name = "Pasta Dishes", slug = "pasta-dishes")),
                categories = listOf(RecipeCategory(id = "c1", name = "Italian", slug = "italian")),
            )
        )
        env.localStore.saveRecipe(
            recipe(
                "2", "Pancakes",
                description = "fluffy breakfast stack",
                ingredients = listOf(RecipeIngredient(food = IngredientFood(name = "flour"))),
                categories = listOf(RecipeCategory(id = "c2", name = "Breakfast", slug = "breakfast")),
            )
        )
        env.localStore.saveRecipe(recipe("3", "Salad", ingredients = listOf(RecipeIngredient(food = IngredientFood(name = "tomato")))))
    }

    // MARK: Local-mode search & filtering

    @Test
    fun `local mode search matches recipe name`() = runTest(mainRule.dispatcher) {
        val env = env()
        seedPantry(env)
        env.vm.setLocalMode(true)

        env.vm.updateSearchText("carbonara")
        advanceUntilIdle()

        assertEquals(listOf("Pasta Carbonara"), env.vm.uiState.value.recipes.map { it.name })
    }

    @Test
    fun `local mode search matches ingredient note and food name`() = runTest(mainRule.dispatcher) {
        val env = env()
        seedPantry(env)
        env.vm.setLocalMode(true)

        env.vm.updateSearchText("guanciale")
        advanceUntilIdle()
        assertEquals(listOf("Pasta Carbonara"), env.vm.uiState.value.recipes.map { it.name })

        env.vm.updateSearchText("tomato")
        advanceUntilIdle()
        assertEquals(listOf("Salad"), env.vm.uiState.value.recipes.map { it.name })
    }

    @Test
    fun `local mode search matches description`() = runTest(mainRule.dispatcher) {
        val env = env()
        seedPantry(env)
        env.vm.setLocalMode(true)

        env.vm.updateSearchText("fluffy")
        advanceUntilIdle()

        assertEquals(listOf("Pancakes"), env.vm.uiState.value.recipes.map { it.name })
    }

    @Test
    fun `local mode filters by category and tag`() = runTest(mainRule.dispatcher) {
        val env = env()
        seedPantry(env)
        env.vm.setLocalMode(true)

        env.vm.selectCategory(RecipeCategory(id = "c2", name = "Breakfast", slug = "breakfast"))
        env.vm.loadRecipes(reset = true)
        assertEquals(listOf("Pancakes"), env.vm.uiState.value.recipes.map { it.name })

        env.vm.selectCategory(null)
        env.vm.selectTag(RecipeTag(id = "t1", name = "Pasta Dishes", slug = "pasta-dishes"))
        env.vm.loadRecipes(reset = true)
        assertEquals(listOf("Pasta Carbonara"), env.vm.uiState.value.recipes.map { it.name })
    }

    @Test
    fun `local mode sorts recipes by name case-insensitively`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.localStore.saveRecipe(recipe("1", "banana bread"))
        env.localStore.saveRecipe(recipe("2", "Apple pie"))
        env.localStore.saveRecipe(recipe("3", "Cherry cake"))
        env.vm.setLocalMode(true)

        env.vm.loadRecipes(reset = true)

        assertEquals(
            listOf("Apple pie", "banana bread", "Cherry cake"),
            env.vm.uiState.value.recipes.map { it.name },
        )
    }

    // MARK: Debounced search

    @Test
    fun `search is debounced 300ms and retyping cancels the pending search`() = runTest(mainRule.dispatcher) {
        val env = env()
        seedPantry(env)
        env.vm.setLocalMode(true)
        env.vm.loadTags() // local mode: derives tags from stored recipes
        val baseline = env.dao.loadAllCalls

        env.vm.updateSearchText("pa")
        advanceTimeBy(200) // t=200: first debounce (fires at 300) still pending
        assertEquals(baseline, env.dao.loadAllCalls)

        env.vm.updateSearchText("pasta")
        advanceTimeBy(200) // t=400: first canceled (would have fired at 300), second fires at 500
        assertEquals(baseline, env.dao.loadAllCalls)

        advanceUntilIdle()
        assertEquals(baseline + 1, env.dao.loadAllCalls)
        assertEquals(listOf("Pasta Carbonara"), env.vm.uiState.value.recipes.map { it.name })
        // matchingTags computed from the tag list
        assertEquals(listOf("pasta-dishes"), env.vm.uiState.value.matchingTags.map { it.slug })
    }

    @Test
    fun `clearing search reloads immediately and clears matching tags`() = runTest(mainRule.dispatcher) {
        val env = env()
        seedPantry(env)
        env.vm.setLocalMode(true)
        env.vm.loadTags()
        env.vm.updateSearchText("pasta")
        advanceUntilIdle()
        assertTrue(env.vm.uiState.value.matchingTags.isNotEmpty())

        env.vm.updateSearchText("")
        advanceUntilIdle()

        assertEquals(3, env.vm.uiState.value.recipes.size)
        assertTrue(env.vm.uiState.value.matchingTags.isEmpty())
    }

    // MARK: API fallback pagination

    @Test
    fun `loadNextPage appends pages and stops at totalPages`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.getRecipesHandler = { page, perPage, _, _, _ ->
            assertEquals(30, perPage)
            RecipePaginatedResponse(
                page = page,
                totalPages = 2,
                items = listOf(
                    RecipeSummary(id = "p$page-1", slug = "p$page-1", name = "Recipe $page-1"),
                    RecipeSummary(id = "p$page-2", slug = "p$page-2", name = "Recipe $page-2"),
                ),
            )
        }

        env.vm.loadRecipes(reset = true)
        assertEquals(2, env.vm.uiState.value.recipes.size)
        assertEquals(1, env.vm.uiState.value.currentPage)
        assertEquals(2, env.vm.uiState.value.totalPages)

        env.vm.loadNextPage()
        assertEquals(4, env.vm.uiState.value.recipes.size)
        assertEquals(2, env.vm.uiState.value.currentPage)
        assertEquals(2, env.api.getRecipesCalls)

        // Guard: already at the last page
        env.vm.loadNextPage()
        assertEquals(4, env.vm.uiState.value.recipes.size)
        assertEquals(2, env.api.getRecipesCalls)
    }

    // MARK: Import (server)

    @Test
    fun `server import fetches new recipe into sync store`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.createRecipeFromURLHandler = { "new-slug" }
        env.api.getRecipeHandler = { slug -> Recipe(id = "rid-1", slug = slug, name = "Imported") }
        env.vm.updateImportURL("https://example.com/recipe")

        val result = env.vm.importFromURL()

        assertTrue(result)
        val state = env.vm.uiState.value
        assertEquals("Recipe imported successfully!", state.importMessage)
        assertEquals("", state.importURL)
        assertFalse(state.isImporting)
        assertEquals("Imported", env.syncService.loadRecipeBySlug("new-slug")?.name)
    }

    @Test
    fun `server import failure shows message`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.createRecipeFromURLHandler = { throw httpException(500, "nope") }
        env.vm.updateImportURL("https://example.com/recipe")

        val result = env.vm.importFromURL()

        assertFalse(result)
        assertEquals("Failed to import recipe. Check the URL.", env.vm.uiState.value.importMessage)
        assertFalse(env.vm.uiState.value.isImporting)
    }

    // MARK: Import (local) duplicate detection

    @Test
    fun `local import detects duplicate by source url`() = runTest(mainRule.dispatcher) {
        val env = env()
        val importURL = "https://example.com/tacos"
        env.localStore.saveRecipe(recipe("existing-1", "Tacos", orgURL = importURL, dateAdded = "2020-01-01T00:00:00Z"))
        env.vm.setLocalMode(true)
        env.parser.handler = { recipe("parsed-1", "Tacos", orgURL = importURL) }
        env.vm.updateImportURL(importURL)

        val result = env.vm.importFromURL()

        assertTrue(result)
        val state = env.vm.uiState.value
        assertTrue(state.showDuplicateAlert)
        assertTrue(state.duplicateMatchedByURL)
        assertEquals("existing-1", state.duplicateRecipe?.id)
        assertEquals("parsed-1", state.pendingImportRecipe?.id)
        assertFalse(state.isImporting)
        // Nothing saved yet
        assertEquals(1, env.dao.count())
    }

    @Test
    fun `local import detects duplicate by name when url differs`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.localStore.saveRecipe(recipe("existing-1", "Tacos", orgURL = "https://old.example/tacos"))
        env.vm.setLocalMode(true)
        env.parser.handler = { recipe("parsed-1", "Tacos", orgURL = "https://new.example/tacos") }
        env.vm.updateImportURL("https://new.example/tacos")

        val result = env.vm.importFromURL()

        assertTrue(result)
        val state = env.vm.uiState.value
        assertTrue(state.showDuplicateAlert)
        assertFalse(state.duplicateMatchedByURL)
        assertEquals("existing-1", state.duplicateRecipe?.id)
    }

    @Test
    fun `confirmImportNew saves the pending recipe as a new entry`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.localStore.saveRecipe(recipe("existing-1", "Tacos"))
        env.vm.setLocalMode(true)
        env.parser.handler = { recipe("parsed-1", "Tacos") }
        env.vm.updateImportURL("https://example.com/tacos")
        env.vm.importFromURL()

        env.vm.confirmImportNew()

        assertEquals(2, env.dao.count())
        val state = env.vm.uiState.value
        assertEquals("Recipe imported successfully!", state.importMessage)
        assertFalse(state.showDuplicateAlert)
        assertNull(state.duplicateRecipe)
        assertNull(state.pendingImportRecipe)
        assertEquals(2, state.recipes.size)
    }

    @Test
    fun `confirmImportUpdate overwrites existing recipe keeping its identity`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.localStore.saveRecipe(recipe("existing-1", "Tacos", dateAdded = "2020-01-01T00:00:00Z"))
        env.vm.setLocalMode(true)
        env.parser.handler = { recipe("parsed-1", "Tacos", description = "much improved") }
        env.vm.updateImportURL("https://example.com/tacos")
        env.vm.importFromURL()

        env.vm.confirmImportUpdate()

        assertEquals(1, env.dao.count())
        val stored = env.localStore.loadRecipe("tacos")
        assertNotNull(stored)
        assertEquals("existing-1", stored?.id) // identity preserved
        assertEquals("2020-01-01T00:00:00Z", stored?.dateAdded)
        assertEquals("much improved", stored?.description) // content from pending
        assertNotNull(stored?.dateUpdated)
        val state = env.vm.uiState.value
        assertEquals("Recipe updated successfully!", state.importMessage)
        assertFalse(state.showDuplicateAlert)
    }

    @Test
    fun `local import maps parser errors to user messages`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.setLocalMode(true)
        env.vm.updateImportURL("https://example.com/nothing")

        env.parser.handler = { throw RecipeParseException.NoRecipeFound() }
        assertFalse(env.vm.importFromURL())
        assertEquals("No recipe found on that page.", env.vm.uiState.value.importMessage)

        env.parser.handler = { throw RecipeParseException.FetchFailed("timeout") }
        assertFalse(env.vm.importFromURL())
        assertEquals("Could not fetch page: timeout", env.vm.uiState.value.importMessage)

        env.parser.handler = { throw RecipeParseException.InvalidUrl() }
        assertFalse(env.vm.importFromURL())
        assertEquals("Invalid URL.", env.vm.uiState.value.importMessage)
    }

    // MARK: Favorites

    @Test
    fun `toggleFavorite optimistically adds and calls api`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.loadFavorites(User(id = "u1", favoriteRecipes = listOf("a")))
        assertTrue(env.vm.isFavorite("a"))

        env.vm.toggleFavorite("b", "u1")

        assertTrue(env.vm.isFavorite("b"))
        assertEquals(listOf("u1" to "b"), env.api.addFavoriteCalls)
    }

    @Test
    fun `toggleFavorite reverts added favorite when api fails`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.addFavoriteHandler = { _, _ -> throw httpException(500, "err") }

        env.vm.toggleFavorite("b", "u1")

        assertFalse(env.vm.isFavorite("b"))
        assertEquals("Failed to update favorite.", env.vm.uiState.value.errorMessage)
        assertEquals("Server error 500: err", env.vm.uiState.value.errorDetail)
    }

    @Test
    fun `toggleFavorite reverts removed favorite when api fails`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.loadFavorites(User(id = "u1", favoriteRecipes = listOf("a")))
        env.api.removeFavoriteHandler = { _, _ -> throw httpException(500, "err") }

        env.vm.toggleFavorite("a", "u1")

        assertTrue(env.vm.isFavorite("a")) // reverted
        assertEquals("Failed to update favorite.", env.vm.uiState.value.errorMessage)
    }

    // MARK: Delete / create (local)

    @Test
    fun `deleteRecipe in local mode removes from store and reloads`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.localStore.saveRecipe(recipe("1", "Tacos"))
        env.vm.setLocalMode(true)

        val result = env.vm.deleteRecipe("tacos")

        assertTrue(result)
        assertEquals(0, env.dao.count())
        assertNull(env.vm.uiState.value.selectedRecipe)
        assertTrue(env.vm.uiState.value.recipes.isEmpty())
    }

    @Test
    fun `createLocalRecipe saves recipe with generated slug and timestamps`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.setLocalMode(true)

        val created = env.vm.createLocalRecipe("My Great Recipe!")

        assertEquals("my-great-recipe", created.slug)
        assertNotNull(created.id)
        assertNotNull(created.dateAdded)
        assertEquals(created.dateAdded, created.dateUpdated)
        assertEquals(1, env.dao.count())
        assertEquals(listOf("My Great Recipe!"), env.vm.uiState.value.recipes.map { it.name })
    }
}
