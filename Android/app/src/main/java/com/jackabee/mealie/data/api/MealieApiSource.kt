package com.jackabee.mealie.data.api

import com.jackabee.mealie.data.auth.ApiSession
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

/**
 * The slice of [MealieApi] the ViewModels depend on, extracted as an interface
 * so unit tests can inject plain fakes (no mocking library, no HTTP stack).
 *
 * Implementations throw retrofit2.HttpException for HTTP errors and
 * java.io.IOException for connectivity failures.
 */
interface MealieApiSource : ApiSession {

    // Auth
    suspend fun login(email: String, password: String): AuthToken
    suspend fun getAppInfo(): AppInfo
    suspend fun getCurrentUser(): User

    // Recipes
    suspend fun getRecipes(
        page: Int = 1,
        perPage: Int = 30,
        search: String? = null,
        categories: List<String>? = null,
        tags: List<String>? = null,
        orderBy: String = "created_at",
        orderDirection: String = "desc",
    ): RecipePaginatedResponse

    suspend fun getRecipe(slug: String): Recipe
    suspend fun createRecipeFromURL(url: String, includeTags: Boolean = true): String
    suspend fun updateRecipe(slug: String, data: Recipe): Recipe
    suspend fun deleteRecipe(slug: String)
    suspend fun uploadRecipeImage(slug: String, imageData: ByteArray)
    fun recipeImageURL(recipeId: String, imageType: String = MealieApi.IMAGE_MIN_ORIGINAL): String

    /** Downloads the recipe's image bytes, or null on any failure (mirrors Swift `try?`). */
    suspend fun downloadRecipeImage(recipeId: String): ByteArray?

    // Favorites
    suspend fun addFavorite(userId: String, slug: String)
    suspend fun removeFavorite(userId: String, slug: String)

    // Categories & Tags
    suspend fun getCategories(): CategoryPaginatedResponse
    suspend fun getTags(): TagPaginatedResponse

    // Meal Plans
    suspend fun getMealPlans(startDate: String, endDate: String): MealPlanPaginatedResponse
    suspend fun getTodayMealPlan(): List<MealPlanEntry>
    suspend fun createMealPlan(plan: CreateMealPlan): MealPlanEntry
    suspend fun deleteMealPlan(id: Int)

    // Shopping Lists
    suspend fun getShoppingLists(): ShoppingListPaginatedResponse
    suspend fun getShoppingList(id: String): ShoppingList
    suspend fun createShoppingList(name: String): ShoppingList
    suspend fun deleteShoppingList(id: String)
    suspend fun addRecipeToShoppingList(listId: String, recipeId: String)
    suspend fun createShoppingListItem(item: CreateShoppingListItem): ShoppingListItem
    suspend fun updateShoppingListItem(item: ShoppingListItem)
    suspend fun deleteShoppingListItem(id: String)
}
