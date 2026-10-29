package com.jackabee.mealie.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.jackabee.mealie.data.api.MealieApiSource
import com.jackabee.mealie.data.auth.AppMode
import com.jackabee.mealie.data.auth.AuthStore
import com.jackabee.mealie.data.auth.SavedServer
import com.jackabee.mealie.data.model.AppInfo
import com.jackabee.mealie.data.model.User
import com.jackabee.mealie.data.store.CacheService
import com.jackabee.mealie.data.store.OfflineRecipeStore
import com.jackabee.mealie.data.store.RecipeSyncService
import com.jackabee.mealie.di.AppContainer
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import retrofit2.HttpException
import java.io.IOException

private const val TAG = "AuthViewModel"

/** UI state for the auth flow. Port of the Swift AuthViewModel's observable properties. */
data class AuthUiState(
    val serverURL: String = "",
    val email: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val errorMessage: String = "",
    val isAuthenticated: Boolean = false,
    val isServerConnected: Boolean = false,
    val currentUser: User? = null,
    val serverInfo: AppInfo? = null,
    val showServerSetup: Boolean = true,
    val savedServers: List<SavedServer> = emptyList(),
    val isLocalMode: Boolean = false,
)

/** Port of ios/Sources/MealieModel/ViewModels/AuthViewModel.swift. */
class AuthViewModel(
    private val authStore: AuthStore,
    private val api: MealieApiSource,
    private val cache: CacheService,
    private val offlineStore: OfflineRecipeStore,
    private val syncService: RecipeSyncService,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    init {
        val savedServers = authStore.savedServers
        if (authStore.savedAppMode == AppMode.LOCAL) {
            _uiState.update {
                it.copy(
                    savedServers = savedServers,
                    isAuthenticated = true,
                    showServerSetup = false,
                    isLocalMode = true,
                )
            }
        } else if (authStore.restoreSession()) {
            _uiState.update {
                it.copy(
                    savedServers = savedServers,
                    isAuthenticated = true,
                    isServerConnected = true,
                    showServerSetup = false,
                    serverURL = authStore.savedServerURL ?: "",
                )
            }
        } else {
            _uiState.update { it.copy(savedServers = savedServers) }
        }
    }

    // MARK: Field updates (two-way bindings in Swift)

    fun updateServerURL(value: String) = _uiState.update { it.copy(serverURL = value) }

    fun updateEmail(value: String) = _uiState.update { it.copy(email = value) }

    fun updatePassword(value: String) = _uiState.update { it.copy(password = value) }

    // MARK: Local mode

    fun enterLocalMode() {
        authStore.startLocalMode()
        _uiState.update { it.copy(isAuthenticated = true, showServerSetup = false, isLocalMode = true) }
    }

    // MARK: Server validation

    suspend fun validateServer() {
        _uiState.update { it.copy(isLoading = true, errorMessage = "") }

        val url = normalizeServerURL(_uiState.value.serverURL)

        try {
            api.configure(url)
            val info = withContext(ioDispatcher) { api.getAppInfo() }
            _uiState.update {
                it.copy(serverInfo = info, showServerSetup = false, serverURL = url, isLoading = false)
            }
        } catch (e: Exception) {
            AppLog.w(TAG, "Server validation failed: $e", e)
            _uiState.update {
                it.copy(
                    errorMessage = "Could not connect to server. Check the URL and try again.",
                    isLoading = false,
                )
            }
        }
    }

    // MARK: Login

    suspend fun login() {
        _uiState.update { it.copy(isLoading = true, errorMessage = "") }
        val state = _uiState.value

        try {
            val token = withContext(ioDispatcher) { api.login(state.email, state.password) }
            api.configure(state.serverURL, token.accessToken)

            val user = withContext(ioDispatcher) { api.getCurrentUser() }

            withContext(ioDispatcher) {
                authStore.saveSession(
                    serverURL = state.serverURL,
                    token = token.accessToken,
                    userId = user.id,
                    email = state.email,
                    password = state.password,
                )
            }

            _uiState.update {
                it.copy(
                    currentUser = user,
                    isAuthenticated = true,
                    isServerConnected = true,
                    isLoading = false,
                    isLocalMode = false,
                    savedServers = authStore.savedServers,
                )
            }
        } catch (e: HttpException) {
            val message = if (e.code() == 401) {
                "Invalid email or password."
            } else {
                "Server error: ${httpErrorBody(e)}"
            }
            _uiState.update { it.copy(errorMessage = message, isLoading = false) }
        } catch (e: SerializationException) {
            AppLog.w(TAG, "Login decoding error: $e", e)
            _uiState.update { it.copy(errorMessage = "Login failed. Please try again.", isLoading = false) }
        } catch (e: IOException) {
            AppLog.w(TAG, "Login error: $e", e)
            _uiState.update { it.copy(errorMessage = "Connection failed. Check your network.", isLoading = false) }
        } catch (e: Exception) {
            AppLog.w(TAG, "Login API error: $e", e)
            _uiState.update { it.copy(errorMessage = "Login failed. Please try again.", isLoading = false) }
        }
    }

    /**
     * Mirrors the Swift views setting `showServerSetup = true` directly
     * ("Change Server" in LoginView, "Connect to Server" in Settings/Sidebar).
     */
    fun showServerSetupForm() {
        _uiState.update { it.copy(showServerSetup = true, errorMessage = "", serverInfo = null) }
    }

    /** Mirrors the Swift SettingsView `.task` fetching app info when missing. */
    suspend fun loadServerInfo() {
        if (_uiState.value.serverInfo != null) return
        try {
            val info = withContext(ioDispatcher) { api.getAppInfo() }
            _uiState.update { it.copy(serverInfo = info) }
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to load server info: $e", e)
        }
    }

    suspend fun loadCurrentUser() {
        try {
            val user = withContext(ioDispatcher) { api.getCurrentUser() }
            _uiState.update { it.copy(currentUser = user) }
        } catch (e: Exception) {
            AppLog.w(TAG, "Failed to load user: $e", e)
        }
    }

    // MARK: Logout

    /**
     * Soft logout: clears auth but preserves server URL and email for quick re-login.
     * Used when the server returns 401 and token refresh fails.
     */
    fun softLogout() {
        authStore.softClearSession()
        _uiState.update {
            it.copy(
                isAuthenticated = false,
                isServerConnected = false,
                serverURL = authStore.savedServerURL ?: "",
                email = authStore.savedEmail ?: "",
                password = "",
                showServerSetup = false, // skip straight to login form
                currentUser = null,
            )
        }
    }

    fun selectSavedServer(server: SavedServer) {
        _uiState.update {
            it.copy(serverURL = server.url, email = server.email, showServerSetup = false, errorMessage = "")
        }
        viewModelScope.launch { validateServer() }
    }

    fun logout() {
        val wasLocal = authStore.savedAppMode == AppMode.LOCAL
        authStore.clearSession()
        if (!wasLocal) {
            viewModelScope.launch(ioDispatcher) {
                cache.clearAll()
                offlineStore.clearAll()
                syncService.clearAll()
            }
        }
        _uiState.update {
            it.copy(
                isAuthenticated = false,
                isServerConnected = false,
                showServerSetup = true,
                currentUser = null,
                email = "",
                password = "",
                serverURL = "",
                savedServers = authStore.savedServers,
                isLocalMode = false,
            )
        }
    }

    companion object {
        /**
         * Trims whitespace and ensures an http(s) scheme. The scheme is matched case-insensitively
         * (the keyboard may auto-capitalize "Https://") and lowercased; bare hosts get `https://`.
         */
        fun normalizeServerURL(raw: String): String {
            val trimmed = raw.trim()
            for (scheme in listOf("https://", "http://")) {
                if (trimmed.startsWith(scheme, ignoreCase = true)) {
                    return scheme + trimmed.substring(scheme.length)
                }
            }
            return "https://$trimmed"
        }

        fun factory(container: AppContainer): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                AuthViewModel(
                    authStore = container.authStore,
                    api = container.api,
                    cache = container.cache,
                    offlineStore = container.offlineRecipeStore,
                    syncService = container.recipeSyncService,
                )
            }
        }
    }
}
