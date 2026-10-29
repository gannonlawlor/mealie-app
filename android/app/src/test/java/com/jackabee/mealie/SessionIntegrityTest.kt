package com.jackabee.mealie

import com.jackabee.mealie.data.auth.ApiSession
import com.jackabee.mealie.data.auth.AuthStore
import com.jackabee.mealie.data.auth.KeyValueStore
import com.jackabee.mealie.data.model.MealieJson
import org.junit.Assert.*
import org.junit.Test

class SessionIntegrityTest {
    private class Api : ApiSession {
        var url = ""
        var token = ""
        override fun configure(baseUrl: String, token: String) { url = baseUrl; this.token = token }
    }
    private class FailingStore(val backing: FakeKeyValueStore) : KeyValueStore by backing {
        var failingKey: String? = null
        override fun putString(key: String, value: String?) {
            if (key == failingKey) error("storage unavailable")
            backing.putString(key, value)
        }
    }

    @Test fun `failure at each save stage never restores mixed server credentials`() {
        for (key in listOf("mealie_server_url", "mealie_access_token", "mealie_user_id",
                           "mealie_app_mode", "mealie_email", "mealie_password", "mealie_saved_servers")) {
            val kv = FailingStore(FakeKeyValueStore())
            val api = Api()
            val store = AuthStore(kv, MealieJson, api)
            store.saveSession("https://old.example", "old-token", "old", "old@example", "old-password")
            kv.failingKey = key
            assertThrows(IllegalStateException::class.java) {
                store.saveSession("https://new.example", "new-token", "new", "new@example", "new-password")
            }
            val restarted = AuthStore(kv, MealieJson, Api())
            assertFalse("failed at $key", restarted.restoreSession())
            assertNull(restarted.savedToken); assertNull(restarted.savedPassword)
            assertEquals("", api.token)
            kv.failingKey = null
            restarted.saveSession("https://new.example", "new-token", "new", "new@example", "new-password")
            assertEquals("https://new.example", restarted.savedServerURL)
            assertEquals("new-token", restarted.savedToken)
        }
    }

    @Test fun `legacy sessions without validity marker still restore`() {
        val kv = FakeKeyValueStore().apply {
            putString("mealie_server_url", "https://old.example")
            putString("mealie_access_token", "old-token")
        }
        assertTrue(AuthStore(kv, MealieJson, Api()).restoreSession())
    }
}
