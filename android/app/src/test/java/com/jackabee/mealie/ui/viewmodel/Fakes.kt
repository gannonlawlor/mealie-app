package com.jackabee.mealie.ui.viewmodel

import com.jackabee.mealie.data.api.MealieApiSource
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
import com.jackabee.mealie.data.parser.RecipeParser
import com.jackabee.mealie.data.store.LocalRecipeDao
import com.jackabee.mealie.data.store.LocalRecipeEntity
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import retrofit2.HttpException
import retrofit2.Response

/** Builds a retrofit HttpException like the real API layer throws on HTTP errors. */
fun httpException(code: Int, body: String = ""): HttpException =
    HttpException(Response.error<Any>(code, body.toResponseBody("application/json".toMediaType())))

/**
 * Hand-rolled fake of the API surface (no mocking library). Every operation has a
 * mutable handler with a sensible default plus call recording where tests need it.
 */
class FakeMealieApiSource : MealieApiSource {

    var configuredBaseUrl: String? = null
    var configuredToken: String? = null

    override fun configure(baseUrl: String, token: String) {
        configuredBaseUrl = baseUrl
        configuredToken = token
    }

    // Auth

    val loginCalls = mutableListOf<Pair<String, String>>()
    var loginHandler: suspend (email: String, password: String) -> AuthToken =
        { _, _ -> AuthToken(accessToken = "test-token", tokenType = "bearer") }

    override suspend fun login(email: String, password: String): AuthToken {
        loginCalls += email to password
        return loginHandler(email, password)
    }

    var appInfoHandler: suspend () -> AppInfo = { AppInfo(version = "2.0.0") }
    override suspend fun getAppInfo(): AppInfo = appInfoHandler()

    var currentUserHandler: suspend () -> User = { User(id = "user-1", email = "user@example.com") }
    override suspend fun getCurrentUser(): User = currentUserHandler()

    // Recipes

    var getRecipesCalls = 0
    var getRecipesHandler: suspend (page: Int, perPage: Int, search: String?, categories: List<String>?, tags: List<String>?) -> RecipePaginatedResponse =
        { _, _, _, _, _ -> RecipePaginatedResponse() }

    override suspend fun getRecipes(
        page: Int,
        perPage: Int,
        search: String?,
        categories: List<String>?,
        tags: List<String>?,
        orderBy: String,
        orderDirection: String,
    ): RecipePaginatedResponse {
        getRecipesCalls += 1
        return getRecipesHandler(page, perPage, search, categories, tags)
    }

    var getRecipeHandler: suspend (slug: String) -> Recipe = { slug -> Recipe(id = "id-$slug", slug = slug) }
    override suspend fun getRecipe(slug: String): Recipe = getRecipeHandler(slug)

    var createRecipeFromURLHandler: suspend (url: String) -> String = { "imported-recipe" }
    override suspend fun createRecipeFromURL(url: String, includeTags: Boolean): String =
        createRecipeFromURLHandler(url)

    var updateRecipeHandler: suspend (slug: String, data: Recipe) -> Recipe = { _, data -> data }
    override suspend fun updateRecipe(slug: String, data: Recipe): Recipe = updateRecipeHandler(slug, data)

    val deletedRecipeSlugs = mutableListOf<String>()
    var deleteRecipeHandler: suspend (slug: String) -> Unit = {}
    override suspend fun deleteRecipe(slug: String) {
        deleteRecipeHandler(slug)
        deletedRecipeSlugs += slug
    }

    val uploadedImages = mutableListOf<Pair<String, ByteArray>>()
    var uploadRecipeImageHandler: suspend (slug: String, imageData: ByteArray) -> Unit = { _, _ -> }
    override suspend fun uploadRecipeImage(slug: String, imageData: ByteArray) {
        uploadRecipeImageHandler(slug, imageData)
        uploadedImages += slug to imageData
    }

    override fun recipeImageURL(recipeId: String, imageType: String): String =
        "https://fake.example/api/media/recipes/$recipeId/images/$imageType"

    var downloadRecipeImageHandler: suspend (recipeId: String) -> ByteArray? = { null }
    override suspend fun downloadRecipeImage(recipeId: String): ByteArray? =
        downloadRecipeImageHandler(recipeId)

    // Favorites

    val addFavoriteCalls = mutableListOf<Pair<String, String>>()
    var addFavoriteHandler: suspend (userId: String, slug: String) -> Unit = { _, _ -> }
    override suspend fun addFavorite(userId: String, slug: String) {
        addFavoriteHandler(userId, slug)
        addFavoriteCalls += userId to slug
    }

    val removeFavoriteCalls = mutableListOf<Pair<String, String>>()
    var removeFavoriteHandler: suspend (userId: String, slug: String) -> Unit = { _, _ -> }
    override suspend fun removeFavorite(userId: String, slug: String) {
        removeFavoriteHandler(userId, slug)
        removeFavoriteCalls += userId to slug
    }

    // Categories & Tags

    var getCategoriesHandler: suspend () -> CategoryPaginatedResponse = { CategoryPaginatedResponse() }
    override suspend fun getCategories(): CategoryPaginatedResponse = getCategoriesHandler()

    var getTagsHandler: suspend () -> TagPaginatedResponse = { TagPaginatedResponse() }
    override suspend fun getTags(): TagPaginatedResponse = getTagsHandler()

    // Meal Plans

    val getMealPlansCalls = mutableListOf<Pair<String, String>>()
    var getMealPlansHandler: suspend (startDate: String, endDate: String) -> MealPlanPaginatedResponse =
        { _, _ -> MealPlanPaginatedResponse() }

    override suspend fun getMealPlans(startDate: String, endDate: String): MealPlanPaginatedResponse {
        getMealPlansCalls += startDate to endDate
        return getMealPlansHandler(startDate, endDate)
    }

    var getTodayMealPlanHandler: suspend () -> List<MealPlanEntry> = { emptyList() }
    override suspend fun getTodayMealPlan(): List<MealPlanEntry> = getTodayMealPlanHandler()

    val createdMealPlans = mutableListOf<CreateMealPlan>()
    var createMealPlanHandler: suspend (plan: CreateMealPlan) -> MealPlanEntry = { plan ->
        MealPlanEntry(id = 1, date = plan.date, entryType = plan.entryType, recipeId = plan.recipeId)
    }

    override suspend fun createMealPlan(plan: CreateMealPlan): MealPlanEntry {
        val entry = createMealPlanHandler(plan)
        createdMealPlans += plan
        return entry
    }

    val deletedMealPlanIds = mutableListOf<Int>()
    var deleteMealPlanHandler: suspend (id: Int) -> Unit = {}
    override suspend fun deleteMealPlan(id: Int) {
        deleteMealPlanHandler(id)
        deletedMealPlanIds += id
    }

    // Shopping Lists

    var getShoppingListsHandler: suspend () -> ShoppingListPaginatedResponse = { ShoppingListPaginatedResponse() }
    override suspend fun getShoppingLists(): ShoppingListPaginatedResponse = getShoppingListsHandler()

    var getShoppingListHandler: suspend (id: String) -> ShoppingList = { id -> ShoppingList(id = id) }
    override suspend fun getShoppingList(id: String): ShoppingList = getShoppingListHandler(id)

    var createShoppingListHandler: suspend (name: String) -> ShoppingList =
        { name -> ShoppingList(id = "list-$name", name = name) }

    override suspend fun createShoppingList(name: String): ShoppingList = createShoppingListHandler(name)

    val deletedShoppingListIds = mutableListOf<String>()
    var deleteShoppingListHandler: suspend (id: String) -> Unit = {}
    override suspend fun deleteShoppingList(id: String) {
        deleteShoppingListHandler(id)
        deletedShoppingListIds += id
    }

    val addRecipeToListCalls = mutableListOf<Pair<String, String>>()
    var addRecipeToShoppingListHandler: suspend (listId: String, recipeId: String) -> Unit = { _, _ -> }
    override suspend fun addRecipeToShoppingList(listId: String, recipeId: String) {
        addRecipeToShoppingListHandler(listId, recipeId)
        addRecipeToListCalls += listId to recipeId
    }

    val createdShoppingListItems = mutableListOf<CreateShoppingListItem>()
    var createShoppingListItemHandler: suspend (item: CreateShoppingListItem) -> ShoppingListItem = { item ->
        ShoppingListItem(
            id = "item-${createdShoppingListItems.size}",
            shoppingListId = item.shoppingListId,
            note = item.note,
            quantity = item.quantity,
            checked = item.checked,
        )
    }

    override suspend fun createShoppingListItem(item: CreateShoppingListItem): ShoppingListItem {
        val created = createShoppingListItemHandler(item)
        createdShoppingListItems += item
        return created
    }

    val updatedShoppingListItems = mutableListOf<ShoppingListItem>()
    var updateShoppingListItemHandler: suspend (item: ShoppingListItem) -> Unit = {}
    override suspend fun updateShoppingListItem(item: ShoppingListItem) {
        updateShoppingListItemHandler(item)
        updatedShoppingListItems += item
    }

    val deletedShoppingListItemIds = mutableListOf<String>()
    var deleteShoppingListItemHandler: suspend (id: String) -> Unit = {}
    override suspend fun deleteShoppingListItem(id: String) {
        deleteShoppingListItemHandler(id)
        deletedShoppingListItemIds += id
    }
}

/** In-memory Room DAO replacement so LocalRecipeStore runs as plain JUnit. */
class FakeLocalRecipeDao : LocalRecipeDao {
    private val rows = LinkedHashMap<String, LocalRecipeEntity>()
    var loadAllCalls = 0

    override suspend fun loadAll(): List<LocalRecipeEntity> {
        loadAllCalls += 1
        return rows.values.toList()
    }

    override suspend fun bySlug(slug: String): LocalRecipeEntity? =
        rows.values.firstOrNull { it.slug == slug }

    override suspend fun byOrgURL(url: String): LocalRecipeEntity? =
        rows.values.firstOrNull { it.orgUrl == url }

    // SQLite LIKE is case-insensitive for ASCII; mirror that.
    override suspend fun byNameLike(name: String): List<LocalRecipeEntity> =
        rows.values.filter { it.name?.contains(name, ignoreCase = true) == true }

    override suspend fun upsert(entity: LocalRecipeEntity) {
        rows[entity.id] = entity
    }

    override suspend fun delete(id: String) {
        rows.remove(id)
    }

    override suspend fun count(): Int = rows.size
}

/** Fake URL parser for the local-mode import flow. */
class FakeRecipeParser : RecipeParser {
    val parsedUrls = mutableListOf<String>()
    var handler: suspend (urlString: String) -> Recipe = { Recipe(id = "parsed-id") }

    override suspend fun parseRecipe(urlString: String): Recipe {
        parsedUrls += urlString
        return handler(urlString)
    }
}
