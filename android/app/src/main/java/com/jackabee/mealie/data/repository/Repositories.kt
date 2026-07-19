package com.jackabee.mealie.data.repository

import com.jackabee.mealie.data.api.MealieApi
import com.jackabee.mealie.data.auth.AuthStore
import com.jackabee.mealie.data.model.AppInfo
import com.jackabee.mealie.data.model.AuthToken
import com.jackabee.mealie.data.model.CategoryPaginatedResponse
import com.jackabee.mealie.data.model.CreateMealPlan
import com.jackabee.mealie.data.model.CreateShoppingListItem
import com.jackabee.mealie.data.model.MealPlanEntry
import com.jackabee.mealie.data.model.MealPlanPaginatedResponse
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipePaginatedResponse
import com.jackabee.mealie.data.model.ShoppingList
import com.jackabee.mealie.data.model.ShoppingListItem
import com.jackabee.mealie.data.model.ShoppingListPaginatedResponse
import com.jackabee.mealie.data.model.TagPaginatedResponse
import com.jackabee.mealie.data.model.User
import com.jackabee.mealie.data.parser.RecipeUrlParser
import com.jackabee.mealie.data.store.CacheService
import com.jackabee.mealie.data.store.LocalGroceryStore
import com.jackabee.mealie.data.store.LocalRecipeStore
import com.jackabee.mealie.data.store.OfflineRecipeStore
import com.jackabee.mealie.data.store.RecipeSyncService

// Thin pass-through repositories. Mode logic (local vs synced vs API fallback)
// lives in the ViewModels, mirroring the Swift ViewModels — these just group
// the dependencies each feature's ViewModel will need.

class AuthRepository(
    val api: MealieApi,
    val authStore: AuthStore,
) {
    suspend fun login(email: String, password: String): AuthToken = api.login(email, password)
    suspend fun getAppInfo(): AppInfo = api.getAppInfo()
    suspend fun getCurrentUser(): User = api.getCurrentUser()
}

class RecipeRepository(
    val api: MealieApi,
    val syncService: RecipeSyncService,
    val localStore: LocalRecipeStore,
    val offlineStore: OfflineRecipeStore,
    val cache: CacheService,
    val urlParser: RecipeUrlParser,
) {
    suspend fun getRecipes(
        page: Int = 1,
        perPage: Int = 30,
        search: String? = null,
        categories: List<String>? = null,
        tags: List<String>? = null,
    ): RecipePaginatedResponse =
        api.getRecipes(page = page, perPage = perPage, search = search, categories = categories, tags = tags)

    suspend fun getRecipe(slug: String): Recipe = api.getRecipe(slug)
    suspend fun createRecipe(name: String): String = api.createRecipe(name)
    suspend fun createRecipeFromURL(url: String, includeTags: Boolean = true): String =
        api.createRecipeFromURL(url, includeTags)

    suspend fun updateRecipe(slug: String, data: Recipe): Recipe = api.updateRecipe(slug, data)
    suspend fun deleteRecipe(slug: String) = api.deleteRecipe(slug)
    suspend fun uploadRecipeImage(slug: String, imageData: ByteArray) =
        api.uploadRecipeImage(slug, imageData)

    suspend fun addFavorite(userId: String, slug: String) = api.addFavorite(userId, slug)
    suspend fun removeFavorite(userId: String, slug: String) = api.removeFavorite(userId, slug)
    suspend fun getCategories(): CategoryPaginatedResponse = api.getCategories()
    suspend fun getTags(): TagPaginatedResponse = api.getTags()
    fun recipeImageURL(recipeId: String, imageType: String = MealieApi.IMAGE_MIN_ORIGINAL): String =
        api.recipeImageURL(recipeId, imageType)
}

class MealPlanRepository(
    val api: MealieApi,
    val cache: CacheService,
) {
    suspend fun getMealPlans(startDate: String, endDate: String): MealPlanPaginatedResponse =
        api.getMealPlans(startDate, endDate)

    suspend fun getTodayMealPlan(): List<MealPlanEntry> = api.getTodayMealPlan()
    suspend fun createMealPlan(plan: CreateMealPlan): MealPlanEntry = api.createMealPlan(plan)
    suspend fun deleteMealPlan(id: Int) = api.deleteMealPlan(id)
}

class ShoppingRepository(
    val api: MealieApi,
    val cache: CacheService,
    val localGroceryStore: LocalGroceryStore,
) {
    suspend fun getShoppingLists(): ShoppingListPaginatedResponse = api.getShoppingLists()
    suspend fun getShoppingList(id: String): ShoppingList = api.getShoppingList(id)
    suspend fun createShoppingList(name: String): ShoppingList = api.createShoppingList(name)
    suspend fun deleteShoppingList(id: String) = api.deleteShoppingList(id)
    suspend fun addRecipeToShoppingList(listId: String, recipeId: String) =
        api.addRecipeToShoppingList(listId, recipeId)

    suspend fun createShoppingListItem(item: CreateShoppingListItem): ShoppingListItem =
        api.createShoppingListItem(item)

    suspend fun updateShoppingListItem(item: ShoppingListItem) = api.updateShoppingListItem(item)
    suspend fun deleteShoppingListItem(id: String) = api.deleteShoppingListItem(id)
}
