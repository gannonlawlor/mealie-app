package com.jackabee.mealie.data.store

import com.jackabee.mealie.data.api.MealieApiSource
import com.jackabee.mealie.data.auth.KeyValueStore
import com.jackabee.mealie.data.model.Recipe
import com.jackabee.mealie.data.model.RecipeSummary
import com.jackabee.mealie.ui.viewmodel.AppLog
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
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
    private val api: MealieApiSource,
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
        get() = syncedIds().count { loadRecipe(it) != null }

    val isSynced: Boolean
        get() = File(dir, summaryIndexFile).exists()

    val totalRecipeCount: Int get() = loadSummaryIndex().size
    val pendingRecipeCount: Int get() {
        val pending = kv.getString("mealie_sync_pending_ids")?.let { json.decodeFromString(idsSerializer, it) }.orEmpty()
        return loadSummaryIndex().count { it.id == null || it.id in pending || loadRecipe(it.id) == null }
    }

    /** Epoch millis of the last completed sync, or null. */
    val lastSyncDate: Long?
        get() = kv.getLong(lastSyncKey)

    // MARK: Sync

    private val syncMutex = Mutex()

    suspend fun syncAll(): Boolean = syncMutex.withLock {
        _isSyncing.value = true
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
                    if (localDates[id] != null && localDates[id] == (summary.dateUpdated ?: "") && loadRecipe(id) != null) {
                        null // already up to date
                    } else {
                        id to slug
                    }
                }

                // 3. Batch-fetch full details, 5 concurrent
                val updatedDates = localDates.toMutableMap()
                val failedIds = mutableSetOf<String>()
                for (batch in toFetch.chunked(batchSize)) {
                    val results = coroutineScope {
                        batch.map { (id, slug) ->
                            async {
                                try {
                                    id to api.getRecipe(slug)
                                } catch (e: CancellationException) {
                                    throw e
                                } catch (e: Exception) {
                                    AppLog.w(TAG, "Failed to fetch recipe $slug: $e", e)
                                    id to null
                                }
                            }
                        }.awaitAll()
                    }
                    for ((id, recipe) in results) {
                        if (recipe != null && recipe.id == id && saveRecipeFile(recipe)) {
                            updatedDates[id] = allSummaries.firstOrNull { it.id == id }?.dateUpdated ?: ""
                        } else {
                            failedIds += id
                            updatedDates.remove(id)
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
                val cachedIds = serverIds.filter { loadRecipe(it) != null }.toSet()
                failedIds += serverIds - cachedIds
                saveSyncedIds(cachedIds)
                saveDateIndex(updatedDates)
                kv.putString("mealie_sync_pending_ids", json.encodeToString(idsSerializer, failedIds))
                check(saveSummaryIndex(allSummaries)) { "Could not save recipe index" }
                val complete = failedIds.isEmpty() && cachedIds.size == allSummaries.size
                if (complete) kv.putLong(lastSyncKey, System.currentTimeMillis())
                complete
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            AppLog.w(TAG, "Recipe sync failed: $e", e)
            false
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
        if (!saveRecipeFile(recipe)) return

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
        kv.remove("mealie_sync_pending_ids")
        _isSyncing.value = false
    }

    // MARK: Private Storage

    private fun saveRecipeFile(recipe: Recipe): Boolean {
        val id = recipe.id ?: return false
        return try {
            dir.mkdirs()
            atomicWrite(File(dir, "recipe_$id.json"), json.encodeToString(Recipe.serializer(), recipe))
            true
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to save synced recipe $id: $e", e)
            false
        }
    }

    private fun removeRecipeFile(id: String) {
        File(dir, "recipe_$id.json").delete()
    }

    private fun saveSummaryIndex(summaries: List<RecipeSummary>): Boolean {
        return try {
            dir.mkdirs()
            atomicWrite(File(dir, summaryIndexFile), json.encodeToString(summarySerializer, summaries))
            true
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to save summary index: $e", e)
            false
        }
    }

    private fun atomicWrite(target: File, text: String) {
        val temporary = File.createTempFile("sync-", ".tmp", dir)
        try {
            temporary.writeText(text)
            java.nio.file.Files.move(temporary.toPath(), target.toPath(),
                java.nio.file.StandardCopyOption.ATOMIC_MOVE, java.nio.file.StandardCopyOption.REPLACE_EXISTING)
        } finally { temporary.delete() }
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
