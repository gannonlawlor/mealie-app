package com.jackabee.mealie

import com.jackabee.mealie.data.auth.ApiSession
import com.jackabee.mealie.data.auth.AppMode
import com.jackabee.mealie.data.auth.AuthStore
import com.jackabee.mealie.data.model.MealieJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class AuthStoreTest {

    private class FakeApiSession : ApiSession {
        var baseUrl: String? = null
        var token: String? = null
        var configureCount = 0

        override fun configure(baseUrl: String, token: String) {
            this.baseUrl = baseUrl
            this.token = token
            configureCount++
        }
    }

    private lateinit var kv: FakeKeyValueStore
    private lateinit var api: FakeApiSession
    private lateinit var store: AuthStore

    @Before
    fun setUp() {
        kv = FakeKeyValueStore()
        api = FakeApiSession()
        store = AuthStore(kv, MealieJson, api)
    }

    @Test
    fun `default app mode is server`() {
        assertEquals(AppMode.SERVER, store.savedAppMode)
    }

    @Test
    fun `saveSession persists everything and configures api`() {
        store.saveSession(
            serverURL = "https://mealie.example.com",
            token = "tok",
            userId = "u1",
            email = "a@b.com",
            password = "secret",
        )
        assertEquals("https://mealie.example.com", store.savedServerURL)
        assertEquals("tok", store.savedToken)
        assertEquals("u1", store.savedUserId)
        assertEquals("a@b.com", store.savedEmail)
        assertEquals("secret", store.savedPassword)
        assertEquals(AppMode.SERVER, store.savedAppMode)
        assertEquals("https://mealie.example.com", api.baseUrl)
        assertEquals("tok", api.token)
        // Also recorded in saved servers list
        assertEquals(1, store.savedServers.size)
        assertEquals("a@b.com", store.savedServers[0].email)
    }

    @Test
    fun `softClearSession keeps url and email for quick re-login`() {
        store.saveSession("https://s", "tok", "u1", "a@b.com", "pw")
        store.softClearSession()
        assertEquals("https://s", store.savedServerURL)
        assertEquals("a@b.com", store.savedEmail)
        assertNull(store.savedToken)
        assertNull(store.savedUserId)
        assertNull(store.savedPassword)
        assertEquals("https://s", api.baseUrl)
        assertEquals("", api.token)
    }

    @Test
    fun `clearSession wipes everything and resets mode`() {
        store.startLocalMode()
        store.saveSession("https://s", "tok", "u1", "a@b.com", "pw")
        store.clearSession()
        assertNull(store.savedServerURL)
        assertNull(store.savedToken)
        assertNull(store.savedUserId)
        assertNull(store.savedEmail)
        assertNull(store.savedPassword)
        assertEquals(AppMode.SERVER, store.savedAppMode)
        assertEquals("", api.baseUrl)
    }

    @Test
    fun `restoreSession requires url and token in server mode`() {
        assertFalse(store.restoreSession())
        store.savedServerURL = "https://s"
        assertFalse(store.restoreSession())
        store.savedToken = "tok"
        assertTrue(store.restoreSession())
        assertEquals("https://s", api.baseUrl)
        assertEquals("tok", api.token)
    }

    @Test
    fun `restoreSession always succeeds in local mode without touching api`() {
        store.startLocalMode()
        assertTrue(store.restoreSession())
        assertEquals(0, api.configureCount)
    }

    @Test
    fun `saved servers are most-recent-first deduped and capped at 5`() {
        for (i in 1..6) {
            store.addSavedServer("https://server$i", "user$i@x.com")
        }
        assertEquals(5, store.savedServers.size)
        assertEquals("https://server6", store.savedServers[0].url)
        assertEquals("https://server2", store.savedServers[4].url)

        // Re-adding an existing URL moves it to the front and updates the email
        store.addSavedServer("https://server3", "new@x.com")
        assertEquals(5, store.savedServers.size)
        assertEquals("https://server3", store.savedServers[0].url)
        assertEquals("new@x.com", store.savedServers[0].email)
        assertEquals(1, store.savedServers.count { it.url == "https://server3" })
    }

    @Test
    fun `removeSavedServer removes only the matching url`() {
        store.addSavedServer("https://a", "a@x.com")
        store.addSavedServer("https://b", "b@x.com")
        store.removeSavedServer("https://a")
        assertEquals(listOf("https://b"), store.savedServers.map { it.url })
    }

    @Test
    fun `onTokenRefreshed persists the new token`() {
        store.saveSession("https://s", "old", "u1")
        store.onTokenRefreshed("new-token")
        assertEquals("new-token", store.savedToken)
    }

    @Test
    fun `pending imports enqueue in order and dedupe`() {
        store.queuePendingImportURL("https://a.example/r1")
        store.queuePendingImportURL("https://b.example/r2")
        store.queuePendingImportURL("https://a.example/r1")
        store.queuePendingImportURL("  ")
        assertEquals(listOf("https://a.example/r1", "https://b.example/r2"), store.pendingImportURLs())
    }

    @Test
    fun `pending imports remove one url and clear the last`() {
        store.queuePendingImportURL("https://a.example/r1")
        store.queuePendingImportURL("https://b.example/r2")
        store.removePendingImportURL("https://a.example/r1")
        assertEquals(listOf("https://b.example/r2"), store.pendingImportURLs())
        store.removePendingImportURL("https://b.example/r2")
        assertEquals(emptyList<String>(), store.pendingImportURLs())
    }

}
