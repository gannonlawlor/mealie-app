package com.jackabee.mealie.data.store

import com.jackabee.mealie.data.auth.KeyValueStore
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.ui.viewmodel.AppLog
import kotlinx.serialization.builtins.SetSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import java.io.File

private const val TAG = "OfflineRecipeStore"

/**
 * Port of ios/Sources/MealieModel/API/OfflineRecipeStore.swift — user-pinned
 * "save for offline" recipes: recipe JSON + image file + id set in prefs.
 */
class OfflineRecipeStore(
    filesRoot: File,
    private val kv: KeyValueStore,
    private val json: Json,
) {

    private val dir = File(filesRoot, "mealie_offline")
    private val imagesDir = File(dir, "images")
    private val idsKey = "mealie_offline_recipe_ids"

    // MARK: Save / Load

    fun saveRecipe(recipe: Recipe, imageData: ByteArray?) {
        val id = recipe.id ?: return
        try {
            dir.mkdirs()
            File(dir, "recipe_$id.json").writeText(json.encodeToString(Recipe.serializer(), recipe))
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to save offline recipe $id: $e", e)
            return
        }

        if (imageData != null) {
            try {
                imagesDir.mkdirs()
                File(imagesDir, "$id.jpg").writeBytes(imageData)
            } catch (e: Exception) {
                AppLog.w(TAG, "Failed to save offline image for $id: $e", e)
            }
        }

        saveSavedIds(savedRecipeIds() + id)
    }

    fun loadRecipe(id: String): Recipe? {
        val file = File(dir, "recipe_$id.json")
        if (!file.exists()) return null
        return try {
            json.decodeFromString(Recipe.serializer(), file.readText())
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to decode offline recipe $id: $e", e)
            null
        }
    }

    fun loadRecipeBySlug(slug: String): Recipe? =
        savedRecipeIds().firstNotNullOfOrNull { id ->
            loadRecipe(id)?.takeIf { it.slug == slug }
        }

    fun loadAllSavedRecipes(): List<Recipe> = savedRecipeIds().mapNotNull { loadRecipe(it) }

    fun removeRecipe(id: String) {
        File(dir, "recipe_$id.json").delete()
        File(imagesDir, "$id.jpg").delete()
        saveSavedIds(savedRecipeIds() - id)
    }

    // MARK: Image

    fun imageFilePath(recipeId: String): String? {
        val file = File(imagesDir, "$recipeId.jpg")
        return if (file.exists()) file.path else null
    }

    // MARK: ID Tracking

    fun isRecipeSavedOffline(id: String): Boolean = savedRecipeIds().contains(id)

    fun savedRecipeIds(): Set<String> {
        val raw = kv.getString(idsKey) ?: return emptySet()
        return try {
            json.decodeFromString(SetSerializer(String.serializer()), raw)
        } catch (_: Exception) {
            emptySet()
        }
    }

    // MARK: Clear

    fun clearAll() {
        dir.deleteRecursively()
        kv.remove(idsKey)
    }

    // MARK: Private

    private fun saveSavedIds(ids: Set<String>) {
        kv.putString(idsKey, json.encodeToString(SetSerializer(String.serializer()), ids))
    }
}
