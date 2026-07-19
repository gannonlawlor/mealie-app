package com.jackabee.mealie

import com.jackabee.mealie.data.auth.KeyValueStore

/** In-memory KeyValueStore so store tests run as plain JUnit without Robolectric. */
class FakeKeyValueStore : KeyValueStore {
    private val strings = mutableMapOf<String, String>()
    private val booleans = mutableMapOf<String, Boolean>()
    private val longs = mutableMapOf<String, Long>()

    override fun getString(key: String): String? = strings[key]

    override fun putString(key: String, value: String?) {
        if (value == null) strings.remove(key) else strings[key] = value
    }

    override fun getBoolean(key: String, default: Boolean): Boolean = booleans[key] ?: default

    override fun putBoolean(key: String, value: Boolean) {
        booleans[key] = value
    }

    override fun getLong(key: String): Long? = longs[key]

    override fun putLong(key: String, value: Long?) {
        if (value == null) longs.remove(key) else longs[key] = value
    }

    override fun contains(key: String): Boolean =
        strings.containsKey(key) || booleans.containsKey(key) || longs.containsKey(key)

    override fun remove(key: String) {
        strings.remove(key)
        booleans.remove(key)
        longs.remove(key)
    }
}
