package com.jackabee.mealie.data.store

import com.jackabee.mealie.data.model.MealPlanEntry
import com.jackabee.mealie.data.model.RecipeCategory
import com.jackabee.mealie.data.model.RecipeTag
import com.jackabee.mealie.data.model.ShoppingList
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Port of ios/Sources/MealieModel/API/CacheService.swift — JSON files in the
 * cache directory for offline-first display of server data.
 */
class CacheService(
    private val cacheDir: File,
    private val json: Json,
) {

    // MARK: Shopping Lists

    fun saveShoppingLists(lists: List<ShoppingList>) =
        save(lists, ListSerializer(ShoppingList.serializer()), "shopping_lists.json")

    fun loadShoppingLists(): List<ShoppingList>? =
        load(ListSerializer(ShoppingList.serializer()), "shopping_lists.json")

    // MARK: Shopping List Detail

    fun saveShoppingListDetail(list: ShoppingList, id: String) =
        save(list, ShoppingList.serializer(), "shopping_list_$id.json")

    fun loadShoppingListDetail(id: String): ShoppingList? =
        load(ShoppingList.serializer(), "shopping_list_$id.json")

    // MARK: Meal Plan Week

    fun saveMealPlanWeek(entries: List<MealPlanEntry>, startDate: String) =
        save(entries, ListSerializer(MealPlanEntry.serializer()), "mealplan_$startDate.json")

    fun loadMealPlanWeek(startDate: String): List<MealPlanEntry>? =
        load(ListSerializer(MealPlanEntry.serializer()), "mealplan_$startDate.json")

    // MARK: Categories & Tags

    fun saveCategories(categories: List<RecipeCategory>) =
        save(categories, ListSerializer(RecipeCategory.serializer()), "categories.json")

    fun loadCategories(): List<RecipeCategory>? =
        load(ListSerializer(RecipeCategory.serializer()), "categories.json")

    fun saveTags(tags: List<RecipeTag>) =
        save(tags, ListSerializer(RecipeTag.serializer()), "tags.json")

    fun loadTags(): List<RecipeTag>? =
        load(ListSerializer(RecipeTag.serializer()), "tags.json")

    // MARK: Clear

    fun clearAll() {
        cacheDir.deleteRecursively()
    }

    // MARK: Private

    private fun <T> save(value: T, serializer: KSerializer<T>, filename: String) {
        try {
            cacheDir.mkdirs()
            File(cacheDir, filename).writeText(json.encodeToString(serializer, value))
        } catch (e: Exception) {
            println("Cache save error ($filename): $e")
        }
    }

    private fun <T> load(serializer: KSerializer<T>, filename: String): T? {
        val file = File(cacheDir, filename)
        if (!file.exists()) return null
        return try {
            json.decodeFromString(serializer, file.readText())
        } catch (e: Exception) {
            println("Cache load error ($filename): $e")
            null
        }
    }
}
