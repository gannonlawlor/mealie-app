package com.jackabee.mealie

import com.jackabee.mealie.data.auth.SecretStore
import com.jackabee.mealie.data.auth.SecureKeyValueStore
import org.junit.Assert.*
import org.junit.Test

class SecureKeyValueStoreTest {
    private class Vault : SecretStore {
        val values = mutableMapOf<String, String>()
        var failWrites = false
        override fun read(key: String) = values[key]
        override fun write(key: String, value: String?) {
            if (failWrites) error("Unavailable")
            if (value == null) values.remove(key) else values[key] = value
        }
    }
    private val token = "mealie_access_token"
    private val password = "mealie_password"

    @Test fun `migrates both secrets but preserves ordinary preferences`() {
        val legacy = FakeKeyValueStore().apply {
            putString(token, "token"); putString(password, "password"); putString("theme", "dark")
        }
        val vault = Vault()
        val store = SecureKeyValueStore(legacy, vault)
        assertEquals("token", store.getString(token))
        assertEquals("password", vault.values[password])
        assertFalse(legacy.contains(token)); assertFalse(legacy.contains(password))
        assertEquals("dark", store.getString("theme"))
    }

    @Test fun `failed migration retains plaintext for retry without using it`() {
        val legacy = FakeKeyValueStore().apply { putString(token, "old") }
        val vault = Vault().apply { failWrites = true }
        val store = SecureKeyValueStore(legacy, vault)
        assertNull(store.getString(token)); assertEquals("old", legacy.getString(token))
        vault.failWrites = false
        assertEquals("old", store.getString(token)); assertFalse(legacy.contains(token))
    }

    @Test fun `new secret failure never falls back to preferences`() {
        val legacy = FakeKeyValueStore()
        val store = SecureKeyValueStore(legacy, Vault().apply { failWrites = true })
        assertThrows(IllegalStateException::class.java) { store.putString(token, "new") }
        assertFalse(legacy.contains(token))
    }

    @Test fun `logout remains revoked when secure deletion temporarily fails`() {
        val legacy = FakeKeyValueStore()
        val vault = Vault().apply { values[token] = "old"; failWrites = true }
        val store = SecureKeyValueStore(legacy, vault)
        store.putString(token, null)
        assertNull(store.getString(token))
        vault.failWrites = false
        assertNull(SecureKeyValueStore(legacy, vault).getString(token))
        assertFalse(vault.values.containsKey(token))
        store.putString(token, "new")
        assertEquals("new", store.getString(token))
    }

    @Test fun `secure value wins over obsolete plaintext`() {
        val legacy = FakeKeyValueStore().apply { putString(token, "old") }
        val vault = Vault().apply { values[token] = "current" }
        val store = SecureKeyValueStore(legacy, vault)
        assertEquals("current", store.getString(token)); assertFalse(legacy.contains(token))
    }
}
