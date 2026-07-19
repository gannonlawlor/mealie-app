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
import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.Field
import retrofit2.http.FormUrlEncoded
import retrofit2.http.GET
import retrofit2.http.HTTP
import retrofit2.http.Multipart
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Part
import retrofit2.http.Path
import retrofit2.http.Query

/** Retrofit interface mirroring ios/Sources/MealieModel/API/MealieAPI.swift endpoint-for-endpoint. */
interface MealieService {

    // MARK: Auth

    @FormUrlEncoded
    @POST("api/auth/token")
    suspend fun login(
        @Field("username") username: String,
        @Field("password") password: String,
    ): AuthToken

    @GET("api/auth/refresh")
    suspend fun refreshToken(): AuthToken

    @GET("api/app/about")
    suspend fun getAppInfo(): AppInfo

    @GET("api/users/self")
    suspend fun getCurrentUser(): User

    // MARK: Recipes

    @GET("api/recipes")
    suspend fun getRecipes(
        @Query("page") page: Int,
        @Query("perPage") perPage: Int,
        @Query("orderBy") orderBy: String,
        @Query("orderDirection") orderDirection: String,
        @Query("search") search: String?,
        @Query("categories") categories: String?,
        @Query("tags") tags: String?,
    ): RecipePaginatedResponse

    @GET("api/recipes/{slug}")
    suspend fun getRecipe(@Path("slug") slug: String): Recipe

    /** Returns the new recipe's slug as a plain JSON string. */
    @POST("api/recipes")
    suspend fun createRecipe(@Body body: CreateRecipe): String

    /** Returns the new recipe's slug as a plain JSON string. */
    @POST("api/recipes/create/url")
    suspend fun createRecipeFromURL(@Body body: CreateRecipeFromURL): String

    @PATCH("api/recipes/{slug}")
    suspend fun updateRecipe(@Path("slug") slug: String, @Body body: Recipe): Recipe

    @DELETE("api/recipes/{slug}")
    suspend fun deleteRecipe(@Path("slug") slug: String)

    @Multipart
    @PUT("api/recipes/{slug}/image")
    suspend fun uploadRecipeImage(
        @Path("slug") slug: String,
        @Part image: MultipartBody.Part,
        @Part("extension") extension: RequestBody,
    )

    // MARK: Favorites

    @POST("api/users/{id}/favorites/{slug}")
    suspend fun addFavorite(@Path("id") userId: String, @Path("slug") slug: String)

    @DELETE("api/users/{id}/favorites/{slug}")
    suspend fun removeFavorite(@Path("id") userId: String, @Path("slug") slug: String)

    // MARK: Categories & Tags

    @GET("api/organizers/categories")
    suspend fun getCategories(@Query("perPage") perPage: Int = -1): CategoryPaginatedResponse

    @GET("api/organizers/tags")
    suspend fun getTags(@Query("perPage") perPage: Int = -1): TagPaginatedResponse

    // MARK: Meal Plans

    @GET("api/households/mealplans")
    suspend fun getMealPlans(
        @Query("start_date") startDate: String,
        @Query("end_date") endDate: String,
        @Query("perPage") perPage: Int = -1,
        @Query("orderBy") orderBy: String = "date",
        @Query("orderDirection") orderDirection: String = "asc",
    ): MealPlanPaginatedResponse

    @GET("api/households/mealplans/today")
    suspend fun getTodayMealPlan(): List<MealPlanEntry>

    @POST("api/households/mealplans")
    suspend fun createMealPlan(@Body body: CreateMealPlan): MealPlanEntry

    @DELETE("api/households/mealplans/{id}")
    suspend fun deleteMealPlan(@Path("id") id: Int)

    // MARK: Shopping Lists

    @GET("api/households/shopping/lists")
    suspend fun getShoppingLists(@Query("perPage") perPage: Int = -1): ShoppingListPaginatedResponse

    @GET("api/households/shopping/lists/{id}")
    suspend fun getShoppingList(@Path("id") id: String): ShoppingList

    @POST("api/households/shopping/lists")
    suspend fun createShoppingList(@Body body: CreateShoppingList): ShoppingList

    @DELETE("api/households/shopping/lists/{id}")
    suspend fun deleteShoppingList(@Path("id") id: String)

    @POST("api/households/shopping/lists/{listId}/recipe/{recipeId}")
    suspend fun addRecipeToShoppingList(
        @Path("listId") listId: String,
        @Path("recipeId") recipeId: String,
    )

    @POST("api/households/shopping/items")
    suspend fun createShoppingListItem(@Body body: CreateShoppingListItem): ShoppingListItem

    /** Body is a LIST containing the single updated item. */
    @PUT("api/households/shopping/items")
    suspend fun updateShoppingListItems(@Body body: List<ShoppingListItem>)

    /** Body is `[{"itemId": id}]`. */
    @HTTP(method = "DELETE", path = "api/households/shopping/items", hasBody = true)
    suspend fun deleteShoppingListItems(@Body body: List<Map<String, String>>)
}
