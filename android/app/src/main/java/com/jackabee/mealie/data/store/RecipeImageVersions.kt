package com.jackabee.mealie.data.store

import com.jackabee.mealie.data.auth.KeyValueStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.UUID

/** Cache keys survive process restarts and change only after a successful replacement. */
class RecipeImageVersions(private val kv: KeyValueStore) {
    private val _changes = MutableStateFlow(0)
    val changes: StateFlow<Int> = _changes
    fun version(id: String): String = kv.getString("recipe_image_version_$id").orEmpty()
    fun invalidate(id: String) {
        kv.putString("recipe_image_version_$id", UUID.randomUUID().toString())
        _changes.value++
    }
}
