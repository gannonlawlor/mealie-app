package com.jackabee.mealie.data.api

import com.jackabee.mealie.data.auth.ApiSession

/**
 * Mutable runtime configuration for the Mealie API, mirroring the Swift
 * MealieAPI singleton's `configure(baseURL:token:)` + `onUnauthorized`.
 *
 * The base URL is user-supplied at runtime, so Retrofit is built against a
 * placeholder URL and [BaseUrlInterceptor] rewrites every request against
 * the current [baseUrl].
 */
class MealieClient : ApiSession {

    @Volatile
    var baseUrl: String = ""
        private set

    @Volatile
    var accessToken: String = ""

    /** Supplies saved credentials for silent re-login after a failed token refresh. */
    @Volatile
    var credentialsProvider: CredentialsProvider? = null

    /**
     * Called when a 401 persists after token refresh + re-login both fail
     * (soft logout). Invoked on an OkHttp worker thread — callers must hop
     * to the main thread themselves.
     */
    @Volatile
    var onUnauthorized: (() -> Unit)? = null

    override fun configure(baseUrl: String, token: String) {
        this.baseUrl = baseUrl.trimEnd('/')
        this.accessToken = token
    }

    val isConfigured: Boolean
        get() = baseUrl.isNotEmpty()
}

/** Implemented by AuthStore: persisted credentials + token write-back. */
interface CredentialsProvider {
    val savedEmail: String?
    val savedPassword: String?

    /** Persist a freshly refreshed access token. */
    fun onTokenRefreshed(token: String)
}
