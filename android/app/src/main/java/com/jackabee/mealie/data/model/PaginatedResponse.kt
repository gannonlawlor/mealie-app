package com.jackabee.mealie.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Mealie pagination is the odd one out: `page`, `total`, `items` are camelCase/plain,
// but `per_page` and `total_pages` are snake_case.
// Generic types were avoided on iOS because of Skip Fuse bridging; concrete classes
// are kept here for one-to-one parity with the Swift models.

@Serializable
data class RecipePaginatedResponse(
    val page: Int = 1,
    @SerialName("per_page") val perPage: Int = 0,
    val total: Int = 0,
    @SerialName("total_pages") val totalPages: Int = 1,
    val items: List<RecipeSummary> = emptyList(),
)

@Serializable
data class CategoryPaginatedResponse(
    val page: Int = 1,
    @SerialName("per_page") val perPage: Int = 0,
    val total: Int = 0,
    @SerialName("total_pages") val totalPages: Int = 1,
    val items: List<RecipeCategory> = emptyList(),
)

@Serializable
data class TagPaginatedResponse(
    val page: Int = 1,
    @SerialName("per_page") val perPage: Int = 0,
    val total: Int = 0,
    @SerialName("total_pages") val totalPages: Int = 1,
    val items: List<RecipeTag> = emptyList(),
)

@Serializable
data class MealPlanPaginatedResponse(
    val page: Int = 1,
    @SerialName("per_page") val perPage: Int = 0,
    val total: Int = 0,
    @SerialName("total_pages") val totalPages: Int = 1,
    val items: List<MealPlanEntry> = emptyList(),
)

@Serializable
data class ShoppingListPaginatedResponse(
    val page: Int = 1,
    @SerialName("per_page") val perPage: Int = 0,
    val total: Int = 0,
    @SerialName("total_pages") val totalPages: Int = 1,
    val items: List<ShoppingList> = emptyList(),
)
