package com.jackabee.mealie.ui.viewmodel

import com.jackabee.mealie.FakeKeyValueStore
import com.jackabee.mealie.data.api.MealieApi
import com.jackabee.mealie.data.api.MealieClient
import com.jackabee.mealie.data.auth.AppMode
import com.jackabee.mealie.data.auth.AuthStore
import com.jackabee.mealie.data.auth.SavedServer
import com.jackabee.mealie.data.model.MealieJson
import com.jackabee.mealie.data.model.RecipeCategory
import com.jackabee.mealie.data.store.CacheService
import com.jackabee.mealie.data.store.OfflineRecipeStore
import com.jackabee.mealie.data.store.RecipeSyncService
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException

class AuthViewModelTest {

    @get:Rule
    val mainRule = MainDispatcherRule()

    @get:Rule
    val tmp = TemporaryFolder()

    private class Env(root: File, rule: MainDispatcherRule) {
        val kv = FakeKeyValueStore()
        val api = FakeMealieApiSource()
        val authStore = AuthStore(kv, MealieJson, api)
        val cache = CacheService(File(root, "cache"), MealieJson)
        val offlineStore = OfflineRecipeStore(File(root, "files"), kv, MealieJson)
        val syncService = RecipeSyncService(File(root, "files"), kv, MealieApi(MealieClient(), MealieJson), MealieJson)
        val vm by lazy { AuthViewModel(authStore, api, cache, offlineStore, syncService, rule.dispatcher) }
    }

    private fun env() = Env(tmp.root, mainRule)

    // MARK: Login

    @Test
    fun `login success authenticates saves session and refreshes saved servers`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.updateServerURL("https://mealie.example")
        env.vm.updateEmail("a@b.com")
        env.vm.updatePassword("secret")

        env.vm.login()

        val state = env.vm.uiState.value
        assertTrue(state.isAuthenticated)
        assertTrue(state.isServerConnected)
        assertFalse(state.isLoading)
        assertEquals("", state.errorMessage)
        assertEquals("user-1", state.currentUser?.id)
        assertFalse(state.isLocalMode)
        // Session persisted, including email + password
        assertEquals("test-token", env.authStore.savedToken)
        assertEquals("a@b.com", env.authStore.savedEmail)
        assertEquals("secret", env.authStore.savedPassword)
        assertEquals("https://mealie.example", env.authStore.savedServerURL)
        assertEquals(AppMode.SERVER, env.authStore.savedAppMode)
        // API configured with the fresh token
        assertEquals("test-token", env.api.configuredToken)
        // Saved-server list refreshed in state
        assertEquals(listOf(SavedServer("https://mealie.example", "a@b.com")), state.savedServers)
    }

    @Test
    fun `login with 401 shows invalid credentials message`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.loginHandler = { _, _ -> throw httpException(401) }
        env.vm.updateEmail("a@b.com")
        env.vm.updatePassword("wrong")

        env.vm.login()

        val state = env.vm.uiState.value
        assertEquals("Invalid email or password.", state.errorMessage)
        assertFalse(state.isAuthenticated)
        assertFalse(state.isLoading)
        assertNull(env.authStore.savedToken)
    }

    @Test
    fun `login with server error shows server error message`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.loginHandler = { _, _ -> throw httpException(500, "boom") }

        env.vm.login()

        assertEquals("Server error: boom", env.vm.uiState.value.errorMessage)
        assertFalse(env.vm.uiState.value.isAuthenticated)
    }

    @Test
    fun `login with network failure shows connection message`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.loginHandler = { _, _ -> throw IOException("unreachable") }

        env.vm.login()

        assertEquals("Connection failed. Check your network.", env.vm.uiState.value.errorMessage)
        assertFalse(env.vm.uiState.value.isAuthenticated)
    }

    // MARK: Server validation

    @Test
    fun `validateServer prefixes https when scheme missing`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.updateServerURL("demo.mealie.example")

        env.vm.validateServer()

        val state = env.vm.uiState.value
        assertEquals("https://demo.mealie.example", state.serverURL)
        assertEquals("https://demo.mealie.example", env.api.configuredBaseUrl)
        assertNotNull(state.serverInfo)
        assertFalse(state.showServerSetup)
        assertFalse(state.isLoading)
    }

    @Test
    fun `validateServer keeps explicit http scheme`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.updateServerURL("http://192.168.1.5:9000")

        env.vm.validateServer()

        assertEquals("http://192.168.1.5:9000", env.api.configuredBaseUrl)
    }

    @Test
    fun `validateServer accepts auto-capitalized scheme`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.updateServerURL("Https://mealie.example ")

        env.vm.validateServer()

        assertEquals("https://mealie.example", env.vm.uiState.value.serverURL)
        assertEquals("https://mealie.example", env.api.configuredBaseUrl)
    }

    @Test
    fun `normalizeServerURL handles scheme case, whitespace and bare hosts`() {
        assertEquals("https://a.example", AuthViewModel.normalizeServerURL("a.example"))
        assertEquals("https://a.example", AuthViewModel.normalizeServerURL("  a.example\n"))
        assertEquals("https://a.example", AuthViewModel.normalizeServerURL("HTTPS://a.example"))
        assertEquals("http://10.0.0.2:9000", AuthViewModel.normalizeServerURL("Http://10.0.0.2:9000"))
        // A host that merely starts with "http" still needs a scheme
        assertEquals("https://httpbin.example", AuthViewModel.normalizeServerURL("httpbin.example"))
    }

    @Test
    fun `validateServer failure shows connection message`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.appInfoHandler = { throw IOException("down") }
        env.vm.updateServerURL("mealie.example")

        env.vm.validateServer()

        val state = env.vm.uiState.value
        assertEquals("Could not connect to server. Check the URL and try again.", state.errorMessage)
        assertTrue(state.showServerSetup)
        assertFalse(state.isLoading)
    }

    // MARK: Soft logout / logout

    @Test
    fun `softLogout keeps url and email but clears password and auth`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.updateServerURL("https://mealie.example")
        env.vm.updateEmail("a@b.com")
        env.vm.updatePassword("secret")
        env.vm.login()

        env.vm.softLogout()

        val state = env.vm.uiState.value
        assertFalse(state.isAuthenticated)
        assertFalse(state.isServerConnected)
        assertEquals("https://mealie.example", state.serverURL)
        assertEquals("a@b.com", state.email)
        assertEquals("", state.password)
        assertFalse(state.showServerSetup) // skip straight to login form
        assertNull(state.currentUser)
        // Store: token + password gone, url + email kept
        assertNull(env.authStore.savedToken)
        assertNull(env.authStore.savedPassword)
        assertEquals("https://mealie.example", env.authStore.savedServerURL)
        assertEquals("a@b.com", env.authStore.savedEmail)
    }

    @Test
    fun `logout in server mode clears session and caches`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.updateServerURL("https://mealie.example")
        env.vm.updateEmail("a@b.com")
        env.vm.updatePassword("secret")
        env.vm.login()
        env.cache.saveCategories(listOf(RecipeCategory(id = "c1", name = "Dinner", slug = "dinner")))

        env.vm.logout()
        advanceUntilIdle()

        val state = env.vm.uiState.value
        assertFalse(state.isAuthenticated)
        assertFalse(state.isServerConnected)
        assertTrue(state.showServerSetup)
        assertNull(state.currentUser)
        assertEquals("", state.email)
        assertEquals("", state.password)
        assertEquals("", state.serverURL)
        assertNull(env.authStore.savedServerURL)
        assertNull(env.authStore.savedToken)
        // Cache wiped in server mode
        assertNull(env.cache.loadCategories())
        // Saved servers survive logout (quick re-login list)
        assertEquals(1, state.savedServers.size)
    }

    @Test
    fun `logout in local mode does not clear caches`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.vm.enterLocalMode()
        env.cache.saveCategories(listOf(RecipeCategory(id = "c1", name = "Dinner", slug = "dinner")))

        env.vm.logout()
        advanceUntilIdle()

        assertFalse(env.vm.uiState.value.isAuthenticated)
        assertFalse(env.vm.uiState.value.isLocalMode)
        assertEquals(AppMode.SERVER, env.authStore.savedAppMode)
        // Cache preserved in local mode
        assertNotNull(env.cache.loadCategories())
    }

    // MARK: Local mode

    @Test
    fun `enterLocalMode authenticates without a server`() = runTest(mainRule.dispatcher) {
        val env = env()

        env.vm.enterLocalMode()

        val state = env.vm.uiState.value
        assertTrue(state.isAuthenticated)
        assertFalse(state.showServerSetup)
        assertTrue(state.isLocalMode)
        assertEquals(AppMode.LOCAL, env.authStore.savedAppMode)
    }

    // MARK: Saved servers

    @Test
    fun `selectSavedServer fills fields and validates`() = runTest(mainRule.dispatcher) {
        val env = env()

        env.vm.selectSavedServer(SavedServer(url = "https://saved.example", email = "saved@b.com"))
        advanceUntilIdle()

        val state = env.vm.uiState.value
        assertEquals("https://saved.example", state.serverURL)
        assertEquals("saved@b.com", state.email)
        assertFalse(state.showServerSetup)
        assertNotNull(state.serverInfo)
        assertEquals("https://saved.example", env.api.configuredBaseUrl)
    }

    // MARK: Init / session restore

    @Test
    fun `init restores saved server session`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.authStore.saveSession(
            serverURL = "https://restored.example",
            token = "old-token",
            userId = "user-1",
            email = "a@b.com",
            password = "secret",
        )

        val state = env.vm.uiState.value
        assertTrue(state.isAuthenticated)
        assertTrue(state.isServerConnected)
        assertFalse(state.showServerSetup)
        assertEquals("https://restored.example", state.serverURL)
        assertEquals(1, state.savedServers.size)
    }

    @Test
    fun `init restores local mode`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.authStore.startLocalMode()

        val state = env.vm.uiState.value
        assertTrue(state.isAuthenticated)
        assertTrue(state.isLocalMode)
        assertFalse(state.showServerSetup)
        assertFalse(state.isServerConnected)
    }

    @Test
    fun `init without session shows server setup`() = runTest(mainRule.dispatcher) {
        val env = env()

        val state = env.vm.uiState.value
        assertFalse(state.isAuthenticated)
        assertTrue(state.showServerSetup)
    }
}
