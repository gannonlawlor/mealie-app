package com.jackabee.mealie.data.settings

import com.jackabee.mealie.data.auth.KeyValueStore

enum class ThemePreference(val raw: String) {
    SYSTEM("system"),
    LIGHT("light"),
    DARK("dark");

    companion object {
        fun fromRaw(raw: String): ThemePreference? = entries.firstOrNull { it.raw == raw }
    }
}

/**
 * Port of ios/Sources/MealieModel/API/AppSettings.swift with the same keys.
 * iOS-only settings (Reminders integration, iCloud sync) are intentionally omitted.
 */
class AppSettings(private val kv: KeyValueStore) {

    private val themeKey = "mealie_app_theme"
    private val keepAwakeKey = "mealie_keep_screen_awake"
    private val localGroceryListKey = "mealie_local_grocery_list"
    private val defaultShoppingListIdKey = "mealie_default_shopping_list_id"
    private val defaultShoppingListNameKey = "mealie_default_shopping_list_name"

    var theme: ThemePreference
        get() = kv.getString(themeKey)?.let { ThemePreference.fromRaw(it) } ?: ThemePreference.SYSTEM
        set(value) = kv.putString(themeKey, value.raw)

    var keepScreenAwake: Boolean
        get() = kv.getBoolean(keepAwakeKey)
        set(value) = kv.putBoolean(keepAwakeKey, value)

    var localGroceryList: Boolean
        get() = kv.getBoolean(localGroceryListKey)
        set(value) = kv.putBoolean(localGroceryListKey, value)

    var defaultShoppingListId: String?
        get() = kv.getString(defaultShoppingListIdKey)
        set(value) = kv.putString(defaultShoppingListIdKey, value)

    var defaultShoppingListName: String?
        get() = kv.getString(defaultShoppingListNameKey)
        set(value) = kv.putString(defaultShoppingListNameKey, value)
}
