package com.jackabee.mealie.data.api

import com.jackabee.mealie.data.model.AppInfo
import com.jackabee.mealie.data.model.AuthToken
import com.jackabee.mealie.data.model.CategoryPaginatedResponse
import com.jackabee.mealie.data.model.CreateMealPlan
import com.jackabee.mealie.data.model.CreateRecipe
import com.jackabee.mealie.data.model.CreateRecipeFromURL
import com.jackabee.mealie.data.model.CreateShoppingList
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
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import java.util.concurrent.TimeUnit

/**
 * High-level API facade mirroring the Swift MealieAPI class. Signatures keep
 * the same defaults as the Swift methods so the ViewModel port is mechanical.
 *
 * HTTP errors surface as retrofit2.HttpException; connectivity errors as IOException.
 */
class MealieApi(
    val client: MealieClient,
    private val json: Json,
    okHttpClient: OkHttpClient? = null,
) {

    private val http: OkHttpClient = okHttpClient ?: OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .addInterceptor(BaseUrlInterceptor(client))
        .addInterceptor(AuthInterceptor(client, json))
        .build()

    private val service: MealieService = Retrofit.Builder()
        .baseUrl(PLACEHOLDER_BASE_URL)
        .client(http)
        .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
        .build()
        .create(MealieService::class.java)

    fun configure(baseUrl: String, token: String = "") = client.configure(baseUrl, token)

    val isConfigured: Boolean get() = client.isConfigured

    // MARK: Auth

    suspend fun login(email: String, password: String): AuthToken = service.login(email, password)

    suspend fun refreshToken(): AuthToken = service.refreshToken()

    suspend fun getAppInfo(): AppInfo = service.getAppInfo()

    suspend fun getCurrentUser(): User = service.getCurrentUser()

    // MARK: Recipes

    suspend fun getRecipes(
        page: Int = 1,
        perPage: Int = 30,
        search: String? = null,
        categories: List<String>? = null,
        tags: List<String>? = null,
        orderBy: String = "created_at",
        orderDirection: String = "desc",
    ): RecipePaginatedResponse = service.getRecipes(
        page = page,
        perPage = perPage,
        orderBy = orderBy,
        orderDirection = orderDirection,
        search = search?.takeIf { it.isNotEmpty() },
        categories = categories?.takeIf { it.isNotEmpty() }?.joinToString(","),
        tags = tags?.takeIf { it.isNotEmpty() }?.joinToString(","),
    )

    suspend fun getRecipe(slug: String): Recipe = service.getRecipe(slug)

    suspend fun createRecipe(name: String): String = service.createRecipe(CreateRecipe(name))

    suspend fun createRecipeFromURL(url: String, includeTags: Boolean = true): String =
        service.createRecipeFromURL(CreateRecipeFromURL(url, includeTags))

    suspend fun updateRecipe(slug: String, data: Recipe): Recipe = service.updateRecipe(slug, data)

    suspend fun deleteRecipe(slug: String) = service.deleteRecipe(slug)

    fun recipeImageURL(recipeId: String, imageType: String = IMAGE_MIN_ORIGINAL): String =
        "${client.baseUrl}/api/media/recipes/$recipeId/images/$imageType"

    suspend fun uploadRecipeImage(slug: String, imageData: ByteArray) {
        val imagePart = MultipartBody.Part.createFormData(
            name = "image",
            filename = "recipe.jpg",
            body = imageData.toRequestBody("image/jpeg".toMediaType()),
        )
        val extensionPart = ".jpg".toRequestBody("text/plain".toMediaType())
        service.uploadRecipeImage(slug, imagePart, extensionPart)
    }

    // MARK: Favorites

    suspend fun addFavorite(userId: String, slug: String) = service.addFavorite(userId, slug)

    suspend fun removeFavorite(userId: String, slug: String) = service.removeFavorite(userId, slug)

    // MARK: Categories & Tags

    suspend fun getCategories(): CategoryPaginatedResponse = service.getCategories()

    suspend fun getTags(): TagPaginatedResponse = service.getTags()

    // MARK: Meal Plans

    suspend fun getMealPlans(startDate: String, endDate: String): MealPlanPaginatedResponse =
        service.getMealPlans(startDate = startDate, endDate = endDate)

    suspend fun getTodayMealPlan(): List<MealPlanEntry> = service.getTodayMealPlan()

    suspend fun createMealPlan(plan: CreateMealPlan): MealPlanEntry = service.createMealPlan(plan)

    suspend fun deleteMealPlan(id: Int) = service.deleteMealPlan(id)

    // MARK: Shopping Lists

    suspend fun getShoppingLists(): ShoppingListPaginatedResponse = service.getShoppingLists()

    suspend fun getShoppingList(id: String): ShoppingList = service.getShoppingList(id)

    suspend fun createShoppingList(name: String): ShoppingList =
        service.createShoppingList(CreateShoppingList(name))

    suspend fun deleteShoppingList(id: String) = service.deleteShoppingList(id)

    suspend fun addRecipeToShoppingList(listId: String, recipeId: String) =
        service.addRecipeToShoppingList(listId, recipeId)

    suspend fun createShoppingListItem(item: CreateShoppingListItem): ShoppingListItem =
        service.createShoppingListItem(item)

    suspend fun updateShoppingListItem(item: ShoppingListItem) =
        service.updateShoppingListItems(listOf(item))

    suspend fun deleteShoppingListItem(id: String) =
        service.deleteShoppingListItems(listOf(mapOf("itemId" to id)))

    companion object {
        const val IMAGE_TINY_ORIGINAL = "tiny-original.webp"
        const val IMAGE_MIN_ORIGINAL = "min-original.webp"
    }
}
