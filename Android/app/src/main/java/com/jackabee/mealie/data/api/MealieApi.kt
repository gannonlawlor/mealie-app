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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
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
) : MealieApiSource {

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

    override fun configure(baseUrl: String, token: String) = client.configure(baseUrl, token)

    val isConfigured: Boolean get() = client.isConfigured

    // MARK: Auth

    override suspend fun login(email: String, password: String): AuthToken = service.login(email, password)

    suspend fun refreshToken(): AuthToken = service.refreshToken()

    override suspend fun getAppInfo(): AppInfo = service.getAppInfo()

    override suspend fun getCurrentUser(): User = service.getCurrentUser()

    // MARK: Recipes

    override suspend fun getRecipes(
        page: Int,
        perPage: Int,
        search: String?,
        categories: List<String>?,
        tags: List<String>?,
        orderBy: String,
        orderDirection: String,
    ): RecipePaginatedResponse = service.getRecipes(
        page = page,
        perPage = perPage,
        orderBy = orderBy,
        orderDirection = orderDirection,
        search = search?.takeIf { it.isNotEmpty() },
        categories = categories?.takeIf { it.isNotEmpty() }?.joinToString(","),
        tags = tags?.takeIf { it.isNotEmpty() }?.joinToString(","),
    )

    override suspend fun getRecipe(slug: String): Recipe = service.getRecipe(slug)

    suspend fun createRecipe(name: String): String = service.createRecipe(CreateRecipe(name))

    override suspend fun createRecipeFromURL(url: String, includeTags: Boolean): String =
        service.createRecipeFromURL(CreateRecipeFromURL(url, includeTags))

    override suspend fun updateRecipe(slug: String, data: Recipe): Recipe = service.updateRecipe(slug, data)

    override suspend fun deleteRecipe(slug: String) = service.deleteRecipe(slug)

    override fun recipeImageURL(recipeId: String, imageType: String): String =
        "${client.baseUrl}/api/media/recipes/$recipeId/images/$imageType"

    override suspend fun downloadRecipeImage(recipeId: String): ByteArray? =
        withContext(Dispatchers.IO) {
            try {
                val request = Request.Builder().url(recipeImageURL(recipeId)).build()
                http.newCall(request).execute().use { response ->
                    if (response.isSuccessful) response.body?.bytes() else null
                }
            } catch (e: Exception) {
                println("Failed to download recipe image $recipeId: $e")
                null
            }
        }

    override suspend fun uploadRecipeImage(slug: String, imageData: ByteArray) {
        val imagePart = MultipartBody.Part.createFormData(
            name = "image",
            filename = "recipe.jpg",
            body = imageData.toRequestBody("image/jpeg".toMediaType()),
        )
        val extensionPart = ".jpg".toRequestBody("text/plain".toMediaType())
        service.uploadRecipeImage(slug, imagePart, extensionPart)
    }

    // MARK: Favorites

    override suspend fun addFavorite(userId: String, slug: String) = service.addFavorite(userId, slug)

    override suspend fun removeFavorite(userId: String, slug: String) = service.removeFavorite(userId, slug)

    // MARK: Categories & Tags

    override suspend fun getCategories(): CategoryPaginatedResponse = service.getCategories()

    override suspend fun getTags(): TagPaginatedResponse = service.getTags()

    // MARK: Meal Plans

    override suspend fun getMealPlans(startDate: String, endDate: String): MealPlanPaginatedResponse =
        service.getMealPlans(startDate = startDate, endDate = endDate)

    override suspend fun getTodayMealPlan(): List<MealPlanEntry> = service.getTodayMealPlan()

    override suspend fun createMealPlan(plan: CreateMealPlan): MealPlanEntry = service.createMealPlan(plan)

    override suspend fun deleteMealPlan(id: Int) = service.deleteMealPlan(id)

    // MARK: Shopping Lists

    override suspend fun getShoppingLists(): ShoppingListPaginatedResponse = service.getShoppingLists()

    override suspend fun getShoppingList(id: String): ShoppingList = service.getShoppingList(id)

    override suspend fun createShoppingList(name: String): ShoppingList =
        service.createShoppingList(CreateShoppingList(name))

    override suspend fun deleteShoppingList(id: String) = service.deleteShoppingList(id)

    override suspend fun addRecipeToShoppingList(listId: String, recipeId: String) =
        service.addRecipeToShoppingList(listId, recipeId)

    override suspend fun createShoppingListItem(item: CreateShoppingListItem): ShoppingListItem =
        service.createShoppingListItem(item)

    override suspend fun updateShoppingListItem(item: ShoppingListItem) =
        service.updateShoppingListItems(listOf(item))

    override suspend fun deleteShoppingListItem(id: String) =
        service.deleteShoppingListItems(listOf(mapOf("itemId" to id)))

    companion object {
        const val IMAGE_TINY_ORIGINAL = "tiny-original.webp"
        const val IMAGE_MIN_ORIGINAL = "min-original.webp"
    }
}
