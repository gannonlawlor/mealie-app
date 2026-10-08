package com.jackabee.mealie.data.store

import com.jackabee.mealie.data.auth.KeyValueStore
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipeSummary
import com.jackabee.mealie.ui.viewmodel.AppLog
import kotlinx.serialization.builtins.SetSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import java.io.File

private const val TAG = "LocalRecipeStore"

/**
 * Port of ios/Sources/MealieModel/API/LocalRecipeStore.swift, backed by Room
 * instead of SwiftData. Recipes are stored as JSON blobs with id/slug/name/orgURL
 * columns for queries; favorites live in prefs; images on disk under
 * filesDir/mealie_local/images.
 */
class LocalRecipeStore(
    private val dao: LocalRecipeDao,
    private val kv: KeyValueStore,
    private val json: Json,
    filesRoot: File,
) {

    private val localDir = File(filesRoot, "mealie_local")
    private val imagesDir = File(localDir, "images")
    private val favoritesKey = "mealie_local_favorites_set"
    private val favoritesSerializer = SetSerializer(String.serializer())

    // MARK: Recipes

    suspend fun loadAllRecipes(): List<Recipe> = dao.loadAll().mapNotNull { decode(it) }

    suspend fun loadRecipe(slug: String): Recipe? = dao.bySlug(slug)?.let { decode(it) }

    suspend fun saveRecipe(recipe: Recipe) {
        val id = recipe.id ?: return
        dao.upsert(
            LocalRecipeEntity(
                id = id,
                slug = recipe.slug,
                name = recipe.name,
                orgUrl = recipe.orgURL,
                json = json.encodeToString(Recipe.serializer(), recipe),
            )
        )
    }

    suspend fun deleteRecipe(id: String) {
        dao.delete(id)
        deleteImage(id)
    }

    suspend fun recipeSummaries(): List<RecipeSummary> = loadAllRecipes().map { recipe ->
        RecipeSummary(
            id = recipe.id, slug = recipe.slug, name = recipe.name,
            description = recipe.description, image = recipe.image,
            recipeCategory = recipe.recipeCategory, tags = recipe.tags,
            rating = recipe.rating, dateAdded = recipe.dateAdded,
            dateUpdated = recipe.dateUpdated,
        )
    }

    suspend fun recipeCount(): Int = dao.count()

    // MARK: Search

    suspend fun findRecipeByOrgURL(url: String): Recipe? = dao.byOrgURL(url)?.let { decode(it) }

    suspend fun findRecipesByName(name: String): List<Recipe> =
        dao.byNameLike(name).mapNotNull { decode(it) }

    // MARK: Favorites (prefs-backed set of slugs)

    fun loadFavorites(): Set<String> {
        val raw = kv.getString(favoritesKey) ?: return emptySet()
        return try {
            json.decodeFromString(favoritesSerializer, raw)
        } catch (_: Exception) {
            emptySet()
        }
    }

    fun saveFavorites(favorites: Set<String>) {
        kv.putString(favoritesKey, json.encodeToString(favoritesSerializer, favorites))
    }

    fun addFavorite(slug: String) = saveFavorites(loadFavorites() + slug)

    fun removeFavorite(slug: String) = saveFavorites(loadFavorites() - slug)

    // MARK: Images

    /** Saves image bytes for a recipe and returns the file path ("" on failure). */
    fun saveImage(data: ByteArray, recipeId: String): String {
        return try {
            imagesDir.mkdirs()
            val file = File(imagesDir, "$recipeId.jpg")
            file.writeBytes(data)
            file.path
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to save image for $recipeId: $e", e)
            ""
        }
    }

    fun imageFilePath(recipeId: String): String? {
        val file = File(imagesDir, "$recipeId.jpg")
        return if (file.exists()) file.path else null
    }

    fun deleteImage(recipeId: String) {
        File(imagesDir, "$recipeId.jpg").delete()
    }

    private fun decode(entity: LocalRecipeEntity): Recipe? = try {
        json.decodeFromString(Recipe.serializer(), entity.json)
    } catch (e: Exception) {
        AppLog.w(TAG, "Failed to decode local recipe ${entity.id}: $e", e)
        null
    }

    companion object {
        /**
         * Mirrors Swift generateSlug: lowercase, spaces -> "-", keep only
         * letters/digits/dashes; falls back to "recipe".
         */
        fun generateSlug(name: String): String {
            val slug = name.lowercase()
                .replace(" ", "-")
                .filter { it.isLetter() || it.isDigit() || it == '-' }
            return slug.ifEmpty { "recipe" }
        }
    }
}
