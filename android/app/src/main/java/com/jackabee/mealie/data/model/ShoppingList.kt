package com.jackabee.mealie.data.model

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.Serializable

/** Ported from ios/Sources/MealieModel/Models/ShoppingList.swift. */
@Serializable
data class ShoppingList(
    val id: String? = null,
    val name: String? = null,
    val groupId: String? = null,
    val householdId: String? = null,
    val listItems: List<ShoppingListItem>? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
) {
    val uncheckedCount: Int
        get() = listItems?.count { it.checked != true } ?: 0

    val checkedCount: Int
        get() = listItems?.count { it.checked == true } ?: 0
}

@Serializable
data class ShoppingListItem(
    val id: String? = null,
    val shoppingListId: String? = null,
    val checked: Boolean? = null,
    val position: Int? = null,
    val isFood: Boolean? = null,
    val note: String? = null,
    val quantity: Double? = null,
    val unit: IngredientUnit? = null,
    val food: IngredientFood? = null,
    val labelId: String? = null,
    val extras: Map<String, String>? = null,
) {
    /** Mirrors Swift `displayText`: "quantity unit food note", falling back to "Item". */
    val displayText: String
        get() {
            val parts = mutableListOf<String>()
            quantity?.takeIf { it > 0 }?.let { q ->
                parts.add(if (q % 1.0 == 0.0) q.toInt().toString() else q.toString())
            }
            unit?.name?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
            food?.name?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
            note?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
            return if (parts.isEmpty()) "Item" else parts.joinToString(" ")
        }
}

@Serializable
data class CreateShoppingList(
    val name: String,
)

@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class CreateShoppingListItem(
    val shoppingListId: String,
    val note: String,
    val quantity: Double? = null,
    @EncodeDefault(EncodeDefault.Mode.ALWAYS) val checked: Boolean = false,
)
