package com.jackabee.mealie.data.model

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Ported from ios/Sources/MealieModel/Models/MealPlan.swift. Note: `id` is Int, not String. */
@Serializable
data class MealPlanEntry(
    val id: Int? = null,
    val date: String? = null,
    val entryType: String? = null,
    val title: String? = null,
    val text: String? = null,
    val recipeId: String? = null,
    val recipe: RecipeSummary? = null,
    val groupId: String? = null,
    val householdId: String? = null,
) {
    /** Mirrors Swift `displayTitle`: recipe name, else title, else "Meal". */
    val displayTitle: String
        get() {
            recipe?.name?.takeIf { it.isNotEmpty() }?.let { return it }
            title?.takeIf { it.isNotEmpty() }?.let { return it }
            return "Meal"
        }

    /** Mirrors Swift `mealType`: falls back to dinner for unknown entry types. */
    val mealType: MealType
        get() = MealType.fromRaw(entryType ?: "") ?: MealType.DINNER
}

@Serializable
enum class MealType(val raw: String) {
    @SerialName("breakfast") BREAKFAST("breakfast"),
    @SerialName("lunch") LUNCH("lunch"),
    @SerialName("dinner") DINNER("dinner"),

    /** Mealie's raw value is "side"; displayed as "Snack" like the iOS app. */
    @SerialName("side") SNACK("side");

    val displayName: String
        get() = when (this) {
            BREAKFAST -> "Breakfast"
            LUNCH -> "Lunch"
            DINNER -> "Dinner"
            SNACK -> "Snack"
        }

    companion object {
        fun fromRaw(raw: String): MealType? = entries.firstOrNull { it.raw == raw }
    }
}

@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class CreateMealPlan(
    val date: String,
    val entryType: String,
    @EncodeDefault(EncodeDefault.Mode.ALWAYS) val title: String = "",
    @EncodeDefault(EncodeDefault.Mode.ALWAYS) val text: String = "",
    val recipeId: String? = null,
)
