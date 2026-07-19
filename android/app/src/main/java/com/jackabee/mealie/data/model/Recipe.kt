package com.jackabee.mealie.data.model

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Ported from ios/Sources/MealieModel/Models/Recipe.swift. All fields nullable so decoding never fails on missing keys. */
@Serializable
data class Recipe(
    val id: String? = null,
    val slug: String? = null,
    val name: String? = null,
    val description: String? = null,
    val image: String? = null,
    val recipeCategory: List<RecipeCategory>? = null,
    val tags: List<RecipeTag>? = null,
    val tools: List<RecipeTool>? = null,
    val rating: Int? = null,
    val recipeYield: String? = null,
    val recipeIngredient: List<RecipeIngredient>? = null,
    val recipeInstructions: List<RecipeInstruction>? = null,
    val totalTime: String? = null,
    val prepTime: String? = null,
    val performTime: String? = null,
    val nutrition: Nutrition? = null,
    val settings: RecipeSettings? = null,
    val dateAdded: String? = null,
    val dateUpdated: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
    val orgURL: String? = null,
    val extras: Map<String, String>? = null,
)

@Serializable
data class RecipeSummary(
    val id: String? = null,
    val slug: String? = null,
    val name: String? = null,
    val description: String? = null,
    val image: String? = null,
    val recipeCategory: List<RecipeCategory>? = null,
    val tags: List<RecipeTag>? = null,
    val rating: Int? = null,
    val dateAdded: String? = null,
    val dateUpdated: String? = null,
)

@Serializable
data class RecipeCategory(
    val id: String? = null,
    val name: String? = null,
    val slug: String? = null,
)

@Serializable
data class RecipeTag(
    val id: String? = null,
    val name: String? = null,
    val slug: String? = null,
)

@Serializable
data class RecipeTool(
    val id: String? = null,
    val name: String? = null,
    val slug: String? = null,
    val onHand: Boolean? = null,
)

@Serializable
data class RecipeIngredient(
    val quantity: Double? = null,
    val unit: IngredientUnit? = null,
    val food: IngredientFood? = null,
    val note: String? = null,
    val isFood: Boolean? = null,
    val disableAmount: Boolean? = null,
    val display: String? = null,
    val title: String? = null,
    val originalText: String? = null,
    val referenceId: String? = null,
) {
    /** Mirrors Swift `displayText`: prefers `display`, else "quantity unit food note". */
    val displayText: String
        get() {
            if (!display.isNullOrEmpty()) return display
            val parts = mutableListOf<String>()
            quantity?.takeIf { it > 0 }?.let { q ->
                parts.add(if (q % 1.0 == 0.0) q.toInt().toString() else q.toString())
            }
            unit?.name?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
            food?.name?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
            note?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
            return parts.joinToString(" ")
        }
}

@Serializable
data class IngredientUnit(
    val id: String? = null,
    val name: String? = null,
    val abbreviation: String? = null,
    val description: String? = null,
)

@Serializable
data class IngredientFood(
    val id: String? = null,
    val name: String? = null,
    val description: String? = null,
    val labelId: String? = null,
)

@Serializable
data class RecipeInstruction(
    val id: String? = null,
    val title: String? = null,
    val text: String? = null,
    val ingredientReferences: List<String>? = null,
)

@Serializable
data class Nutrition(
    val calories: String? = null,
    val fatContent: String? = null,
    val proteinContent: String? = null,
    val carbohydrateContent: String? = null,
    val fiberContent: String? = null,
    val sodiumContent: String? = null,
    val sugarContent: String? = null,
)

@Serializable
data class RecipeSettings(
    @SerialName("public") val isPublic: Boolean? = null,
    val showNutrition: Boolean? = null,
    val showAssets: Boolean? = null,
    val landscapeView: Boolean? = null,
    val disableComments: Boolean? = null,
    val disableAmount: Boolean? = null,
)

@Serializable
data class CreateRecipe(
    val name: String,
)

@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class CreateRecipeFromURL(
    val url: String,
    @EncodeDefault(EncodeDefault.Mode.ALWAYS) val includeTags: Boolean = true,
)
