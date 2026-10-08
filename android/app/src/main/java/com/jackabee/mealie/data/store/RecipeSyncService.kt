package com.jackabee.mealie.data.store

import com.jackabee.mealie.data.api.MealieApi
import com.jackabee.mealie.data.auth.KeyValueStore
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipeSummary
import com.jackabee.mealie.ui.viewmodel.AppLog
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.SetSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import java.io.File

private const val TAG = "RecipeSyncService"

/**
 * Port of ios/Sources/MealieModel/API/RecipeSyncService.swift — mirrors the
 * whole server recipe collection to local JSON files for offline use and
 * client-side (e.g. ingredient) search.
 *
 * Files live in filesDir/mealie_recipe_sync; the synced-id set, per-recipe
 * dateUpdated index, and last-sync timestamp live in prefs.
 */
class RecipeSyncService(
    filesRoot: File,
    private val kv: KeyValueStore,
    private val api: MealieApi,
    private val json: Json,
) {

    private val dir = File(filesRoot, "mealie_recipe_sync")
    private val summaryIndexFile = "recipe_summaries.json"
    private val idsKey = "mealie_sync_recipe_ids"
    private val lastSyncKey = "mealie_sync_last_date"
    private val dateIndexKey = "mealie_sync_date_index"
    private val batchSize = 5

    private val idsSerializer = SetSerializer(String.serializer())
    private val dateIndexSerializer = MapSerializer(String.serializer(), String.serializer())
    private val summarySerializer = ListSerializer(RecipeSummary.serializer())

    // MARK: Observable State

    private val _isSyncing = MutableStateFlow(false)
    val isSyncing: StateFlow<Boolean> = _isSyncing

    val syncedRecipeCount: Int
        get() = syncedIds().size

    val isSynced: Boolean
        get() = kv.contains(lastSyncKey)

    /** Epoch millis of the last completed sync, or null. */
    val lastSyncDate: Long?
        get() = kv.getLong(lastSyncKey)

    // MARK: Sync

    suspend fun syncAll() {
        if (!_isSyncing.compareAndSet(expect = false, update = true)) return
        try {
            withContext(Dispatchers.IO) {
                // 1. Fetch all recipe summaries from server (paged)
                val allSummaries = mutableListOf<RecipeSummary>()
                var page = 1
                var totalPages = 1
                while (page <= totalPages) {
                    val response = api.getRecipes(page = page, perPage = 50)
                    allSummaries += response.items
                    totalPages = response.totalPages
                    page += 1
                }

                // 2. Determine which recipes need fetching (incremental by dateUpdated)
                val serverIds = allSummaries.mapNotNull { it.id }.toSet()
                val localIds = syncedIds()
                val localDates = loadDateIndex()

                val toFetch = allSummaries.mapNotNull { summary ->
                    val id = summary.id ?: return@mapNotNull null
                    val slug = summary.slug ?: return@mapNotNull null
                    if (localDates[id] != null && localDates[id] == (summary.dateUpdated ?: "")) {
                        null // already up to date
                    } else {
                        id to slug
                    }
                }

                // 3. Batch-fetch full details, 5 concurrent
                val updatedDates = localDates.toMutableMap()
                for (batch in toFetch.chunked(batchSize)) {
                    val results = coroutineScope {
                        batch.map { (id, slug) ->
                            async {
                                try {
                                    id to api.getRecipe(slug)
                                } catch (e: Exception) {
                                    AppLog.w(TAG, "Failed to fetch recipe $slug: $e", e)
                                    id to null
                                }
                            }
                        }.awaitAll()
                    }
                    for ((id, recipe) in results) {
                        if (recipe != null) {
                            saveRecipeFile(recipe)
                            updatedDates[id] = recipe.dateUpdated ?: recipe.updatedAt ?: ""
                        }
                    }
                }

                // 4. Remove recipes deleted from server
                val deletedIds = localIds - serverIds
                for (id in deletedIds) {
                    removeRecipeFile(id)
                    updatedDates.remove(id)
                }

                // 5. Update tracking and summary index
                saveSyncedIds(serverIds)
                saveDateIndex(updatedDates)
                saveSummaryIndex(allSummaries)
                kv.putLong(lastSyncKey, System.currentTimeMillis())
            }
        } catch (e: Exception) {
            AppLog.w(TAG, "Recipe sync failed: $e", e)
        } finally {
            _isSyncing.value = false
        }
    }

    // MARK: Read (Summary Index)

    fun loadSummaryIndex(): List<RecipeSummary> {
        val file = File(dir, summaryIndexFile)
        if (!file.exists()) return emptyList()
        return try {
            json.decodeFromString(summarySerializer, file.readText())
        } catch (_: Exception) {
            emptyList()
        }
    }

    // MARK: Read (Full Recipes)

    fun loadAllSyncedRecipes(): List<Recipe> = syncedIds().mapNotNull { loadRecipe(it) }

    fun loadRecipe(id: String): Recipe? {
        val file = File(dir, "recipe_$id.json")
        if (!file.exists()) return null
        return try {
            json.decodeFromString(Recipe.serializer(), file.readText())
        } catch (_: Exception) {
            null
        }
    }

    fun loadRecipeBySlug(slug: String): Recipe? {
        val id = loadSummaryIndex().firstOrNull { it.slug == slug }?.id ?: return null
        return loadRecipe(id)
    }

    // MARK: Targeted Updates (after writes)

    fun updateRecipe(recipe: Recipe) {
        saveRecipeFile(recipe)

        // Update summary index
        val summaries = loadSummaryIndex().toMutableList()
        val summary = RecipeSummary(
            id = recipe.id, slug = recipe.slug, name = recipe.name,
            description = recipe.description, image = recipe.image,
            recipeCategory = recipe.recipeCategory, tags = recipe.tags,
            rating = recipe.rating, dateAdded = recipe.dateAdded,
            dateUpdated = recipe.dateUpdated,
        )
        val idx = summaries.indexOfFirst { it.id == recipe.id }
        if (idx >= 0) {
            summaries[idx] = summary
        } else {
            summaries.add(0, summary)
            recipe.id?.let { saveSyncedIds(syncedIds() + it) }
        }
        saveSummaryIndex(summaries)

        // Update date index
        recipe.id?.let { id ->
            val dates = loadDateIndex().toMutableMap()
            dates[id] = recipe.dateUpdated ?: recipe.updatedAt ?: ""
            saveDateIndex(dates)
        }
    }

    fun removeRecipe(slug: String) {
        val summaries = loadSummaryIndex().toMutableList()
        val id = summaries.firstOrNull { it.slug == slug }?.id ?: return

        removeRecipeFile(id)
        summaries.removeAll { it.id == id }
        saveSummaryIndex(summaries)

        saveSyncedIds(syncedIds() - id)

        val dates = loadDateIndex().toMutableMap()
        dates.remove(id)
        saveDateIndex(dates)
    }

    // MARK: Clear

    fun clearAll() {
        dir.deleteRecursively()
        kv.remove(idsKey)
        kv.remove(lastSyncKey)
        kv.remove(dateIndexKey)
        _isSyncing.value = false
    }

    // MARK: Private Storage

    private fun saveRecipeFile(recipe: Recipe) {
        val id = recipe.id ?: return
        try {
            dir.mkdirs()
            File(dir, "recipe_$id.json").writeText(json.encodeToString(Recipe.serializer(), recipe))
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to save synced recipe $id: $e", e)
        }
    }

    private fun removeRecipeFile(id: String) {
        File(dir, "recipe_$id.json").delete()
    }

    private fun saveSummaryIndex(summaries: List<RecipeSummary>) {
        try {
            dir.mkdirs()
            File(dir, summaryIndexFile).writeText(json.encodeToString(summarySerializer, summaries))
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to save summary index: $e", e)
        }
    }

    // MARK: ID Tracking

    private fun syncedIds(): Set<String> {
        val raw = kv.getString(idsKey) ?: return emptySet()
        return try {
            json.decodeFromString(idsSerializer, raw)
        } catch (_: Exception) {
            emptySet()
        }
    }

    private fun saveSyncedIds(ids: Set<String>) {
        kv.putString(idsKey, json.encodeToString(idsSerializer, ids))
    }

    // MARK: Date Index (for incremental sync)

    private fun loadDateIndex(): Map<String, String> {
        val raw = kv.getString(dateIndexKey) ?: return emptyMap()
        return try {
            json.decodeFromString(dateIndexSerializer, raw)
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun saveDateIndex(index: Map<String, String>) {
        kv.putString(dateIndexKey, json.encodeToString(dateIndexSerializer, index))
    }
}
