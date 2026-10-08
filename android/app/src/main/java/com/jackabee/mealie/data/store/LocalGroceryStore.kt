package com.jackabee.mealie.data.store

import com.jackabee.mealie.data.auth.KeyValueStore
import com.jackabee.mealie.ui.viewmodel.AppLog
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import java.util.UUID

private const val TAG = "LocalGroceryStore"

@Serializable
data class PendingGroceryItem(
    val id: String = UUID.randomUUID().toString(),
    val shoppingListId: String,
    val note: String,
    val quantity: Double? = null,
)

/**
 * Port of ios/Sources/MealieModel/API/LocalGroceryStore.swift — grocery items
 * added while offline / in local-grocery mode, keyed by shopping list id.
 */
class LocalGroceryStore(
    private val kv: KeyValueStore,
    private val json: Json,
) {

    private val storageKey = "mealie_pending_grocery_items"
    private val mapSerializer =
        MapSerializer(String.serializer(), ListSerializer(PendingGroceryItem.serializer()))

    fun loadAllPending(): Map<String, List<PendingGroceryItem>> {
        val raw = kv.getString(storageKey) ?: return emptyMap()
        return try {
            json.decodeFromString(mapSerializer, raw)
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to decode pending grocery items: $e", e)
            emptyMap()
        }
    }

    fun pendingItems(listId: String): List<PendingGroceryItem> =
        loadAllPending()[listId] ?: emptyList()

    fun addPendingItem(item: PendingGroceryItem, listId: String) {
        val all = loadAllPending().toMutableMap()
        all[listId] = (all[listId] ?: emptyList()) + item
        save(all)
    }

    fun removePendingItem(index: Int, listId: String) {
        val all = loadAllPending().toMutableMap()
        val items = all[listId]?.toMutableList() ?: return
        if (index >= items.size) return
        items.removeAt(index)
        if (items.isEmpty()) all.remove(listId) else all[listId] = items
        save(all)
    }

    fun clearPendingItems(listId: String) {
        val all = loadAllPending().toMutableMap()
        all.remove(listId)
        save(all)
    }

    fun totalPendingCount(): Int = loadAllPending().values.sumOf { it.size }

    fun pendingCount(listId: String): Int = pendingItems(listId).size

    private fun save(data: Map<String, List<PendingGroceryItem>>) {
        try {
            kv.putString(storageKey, json.encodeToString(mapSerializer, data))
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to encode pending grocery items: $e", e)
        }
    }
}
