package com.jackabee.mealie.data.auth

import com.jackabee.mealie.data.api.CredentialsProvider
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

enum class AppMode(val raw: String) {
    LOCAL("local"),
    SERVER("server");

    companion object {
        fun fromRaw(raw: String): AppMode? = entries.firstOrNull { it.raw == raw }
    }
}

@Serializable
data class SavedServer(
    val url: String,
    val email: String,
)

/** Something that can be (re)configured with a base URL + token; implemented by MealieClient. */
interface ApiSession {
    fun configure(baseUrl: String, token: String = "")
}

/**
 * Port of ios/Sources/MealieModel/API/AuthService.swift, using the same
 * preference keys and session semantics.
 */
class AuthStore(
    private val kv: KeyValueStore,
    private val json: Json,
    private val api: ApiSession,
) : CredentialsProvider {

    private val serverURLKey = "mealie_server_url"
    private val tokenKey = "mealie_access_token"
    private val userIdKey = "mealie_user_id"
    private val appModeKey = "mealie_app_mode"
    private val emailKey = "mealie_email"
    private val passwordKey = "mealie_password"
    private val savedServersKey = "mealie_saved_servers"

    // MARK: App Mode

    var savedAppMode: AppMode
        get() = AppMode.fromRaw(kv.getString(appModeKey) ?: "server") ?: AppMode.SERVER
        set(value) = kv.putString(appModeKey, value.raw)

    fun startLocalMode() {
        savedAppMode = AppMode.LOCAL
    }

    // MARK: Credentials

    var savedServerURL: String?
        get() = kv.getString(serverURLKey)
        set(value) = kv.putString(serverURLKey, value)

    var savedToken: String?
        get() = kv.getString(tokenKey)
        set(value) = kv.putString(tokenKey, value)

    var savedUserId: String?
        get() = kv.getString(userIdKey)
        set(value) = kv.putString(userIdKey, value)

    override var savedEmail: String?
        get() = kv.getString(emailKey)
        set(value) = kv.putString(emailKey, value)

    override var savedPassword: String?
        get() = kv.getString(passwordKey)
        set(value) = kv.putString(passwordKey, value)

    override fun onTokenRefreshed(token: String) {
        savedToken = token
    }

    // MARK: Saved Servers (max 5, most-recent-first)

    var savedServers: List<SavedServer>
        get() {
            val raw = kv.getString(savedServersKey) ?: return emptyList()
            return try {
                json.decodeFromString(ListSerializer(SavedServer.serializer()), raw)
            } catch (_: Exception) {
                emptyList()
            }
        }
        set(value) {
            kv.putString(savedServersKey, json.encodeToString(ListSerializer(SavedServer.serializer()), value))
        }

    fun addSavedServer(url: String, email: String) {
        var servers = savedServers.filterNot { it.url == url }.toMutableList()
        servers.add(0, SavedServer(url = url, email = email))
        if (servers.size > 5) servers = servers.take(5).toMutableList()
        savedServers = servers
    }

    fun removeSavedServer(url: String) {
        savedServers = savedServers.filterNot { it.url == url }
    }

    // MARK: Session

    /** Returns true when a usable session exists (local mode, or saved URL + token). */
    fun restoreSession(): Boolean {
        if (savedAppMode == AppMode.LOCAL) return true
        val url = savedServerURL?.takeIf { it.isNotEmpty() } ?: return false
        val token = savedToken?.takeIf { it.isNotEmpty() } ?: return false
        api.configure(url, token)
        return true
    }

    fun saveSession(
        serverURL: String,
        token: String,
        userId: String,
        email: String? = null,
        password: String? = null,
    ) {
        savedServerURL = serverURL
        savedToken = token
        savedUserId = userId
        savedAppMode = AppMode.SERVER
        if (email != null) savedEmail = email
        if (password != null) savedPassword = password
        if (email != null) addSavedServer(url = serverURL, email = email)
        api.configure(serverURL, token)
    }

    /** Clears auth token but preserves server URL and email for quick re-login. */
    fun softClearSession() {
        savedToken = null
        savedUserId = null
        savedPassword = null
        api.configure(savedServerURL ?: "", "")
    }

    fun clearSession() {
        savedServerURL = null
        savedToken = null
        savedUserId = null
        savedEmail = null
        savedPassword = null
        savedAppMode = AppMode.SERVER
        api.configure("", "")
    }
}
