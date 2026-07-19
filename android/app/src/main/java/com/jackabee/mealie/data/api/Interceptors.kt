package com.jackabee.mealie.data.api

import com.jackabee.mealie.data.model.AuthToken
import kotlinx.serialization.json.Json
import okhttp3.FormBody
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Interceptor
import okhttp3.Request
import okhttp3.Response
import java.io.IOException

/** Placeholder Retrofit base URL; every request is rewritten by [BaseUrlInterceptor]. */
const val PLACEHOLDER_BASE_URL = "http://mealie.invalid/"

/**
 * Rewrites requests aimed at the placeholder host onto the user-configured base
 * URL (which may include a sub-path, e.g. https://host/mealie).
 */
class BaseUrlInterceptor(private val client: MealieClient) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        if (request.url.host != "mealie.invalid") {
            return chain.proceed(request)
        }
        val base = client.baseUrl
        if (base.isEmpty()) {
            throw IOException("Mealie API is not configured (no server URL)")
        }
        val pathAndQuery = request.url.encodedPath +
            (request.url.encodedQuery?.let { "?$it" } ?: "")
        val newUrl = (base + pathAndQuery).toHttpUrlOrNull()
            ?: throw IOException("Invalid Mealie server URL: $base")
        return chain.proceed(request.newBuilder().url(newUrl).build())
    }
}

/**
 * Replicates the Swift 401 flow from MealieAPI.swift:
 * on 401 -> GET /api/auth/refresh with the current token -> on failure,
 * re-login with saved email/password -> retry the original request once ->
 * if still 401, invoke onUnauthorized (soft logout).
 */
class AuthInterceptor(
    private val client: MealieClient,
    private val json: Json,
) : Interceptor {

    private val refreshLock = Any()

    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        val path = original.url.encodedPath
        val isLogin = path.endsWith("/api/auth/token")
        val isRefresh = path.endsWith("/api/auth/refresh")

        var request = original
        if (!isLogin && client.accessToken.isNotEmpty()) {
            request = original.newBuilder()
                .header("Authorization", "Bearer ${client.accessToken}")
                .build()
        }
        if (request.header("Accept") == null) {
            request = request.newBuilder().header("Accept", "application/json").build()
        }

        val response = chain.proceed(request)
        if (response.code != 401 || isLogin || isRefresh) {
            return response
        }

        val refreshed = synchronized(refreshLock) { attemptTokenRefresh(chain) }
        if (!refreshed) {
            client.onUnauthorized?.invoke()
            return response
        }

        response.close()
        val retry = original.newBuilder()
            .header("Authorization", "Bearer ${client.accessToken}")
            .build()
        val retryResponse = chain.proceed(retry)
        if (retryResponse.code == 401) {
            client.onUnauthorized?.invoke()
        }
        return retryResponse
    }

    /** Try the refresh endpoint, then fall back to re-login with saved credentials. */
    private fun attemptTokenRefresh(chain: Interceptor.Chain): Boolean {
        // 1. GET /api/auth/refresh with the current token
        try {
            val refreshRequest = Request.Builder()
                .url("${client.baseUrl}/api/auth/refresh")
                .header("Authorization", "Bearer ${client.accessToken}")
                .header("Accept", "application/json")
                .get()
                .build()
            chain.proceed(refreshRequest).use { resp ->
                if (resp.isSuccessful) {
                    val body = resp.body?.string() ?: ""
                    val token = json.decodeFromString(AuthToken.serializer(), body)
                    client.accessToken = token.accessToken
                    client.credentialsProvider?.onTokenRefreshed(token.accessToken)
                    return true
                }
            }
        } catch (_: Exception) {
            // fall through to re-authentication
        }

        // 2. Re-login with saved credentials
        val email = client.credentialsProvider?.savedEmail ?: return false
        val password = client.credentialsProvider?.savedPassword ?: return false
        return try {
            val loginRequest = Request.Builder()
                .url("${client.baseUrl}/api/auth/token")
                .header("Accept", "application/json")
                .post(
                    FormBody.Builder()
                        .add("username", email)
                        .add("password", password)
                        .build()
                )
                .build()
            chain.proceed(loginRequest).use { resp ->
                if (!resp.isSuccessful) return false
                val body = resp.body?.string() ?: ""
                val token = json.decodeFromString(AuthToken.serializer(), body)
                client.accessToken = token.accessToken
                client.credentialsProvider?.onTokenRefreshed(token.accessToken)
                true
            }
        } catch (_: Exception) {
            false
        }
    }
}
