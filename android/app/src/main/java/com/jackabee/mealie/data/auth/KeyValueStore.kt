package com.jackabee.mealie.data.auth

import android.content.Context
import android.content.SharedPreferences

/**
 * Minimal key-value abstraction over SharedPreferences (the Android analogue of
 * UserDefaults.standard on iOS). Abstracted behind an interface so unit tests
 * can use an in-memory fake without Robolectric.
 */
interface KeyValueStore {
    fun getString(key: String): String?
    fun putString(key: String, value: String?)
    fun getBoolean(key: String, default: Boolean = false): Boolean
    fun putBoolean(key: String, value: Boolean)
    fun putBooleanDurably(key: String, value: Boolean) { putBoolean(key, value) }
    fun getLong(key: String): Long?
    fun putLong(key: String, value: Long?)
    fun contains(key: String): Boolean
    fun remove(key: String)
}

class SharedPrefsKeyValueStore(context: Context, name: String = "mealie_prefs") : KeyValueStore {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(name, Context.MODE_PRIVATE)

    override fun getString(key: String): String? = prefs.getString(key, null)

    override fun putString(key: String, value: String?) {
        if (value == null) prefs.edit().remove(key).apply()
        else prefs.edit().putString(key, value).apply()
    }

    override fun getBoolean(key: String, default: Boolean): Boolean = prefs.getBoolean(key, default)

    override fun putBoolean(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
    }

    override fun putBooleanDurably(key: String, value: Boolean) {
        check(prefs.edit().putBoolean(key, value).commit()) { "Unable to save session state" }
    }

    override fun getLong(key: String): Long? =
        if (prefs.contains(key)) prefs.getLong(key, 0L) else null

    override fun putLong(key: String, value: Long?) {
        if (value == null) prefs.edit().remove(key).apply()
        else prefs.edit().putLong(key, value).apply()
    }

    override fun contains(key: String): Boolean = prefs.contains(key)

    override fun remove(key: String) {
        prefs.edit().remove(key).apply()
    }
}
