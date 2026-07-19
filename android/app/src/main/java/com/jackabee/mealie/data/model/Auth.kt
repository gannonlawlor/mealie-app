package com.jackabee.mealie.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Auth token uses snake_case keys — the one endpoint that does (besides pagination fields). */
@Serializable
data class AuthToken(
    @SerialName("access_token") val accessToken: String,
    @SerialName("token_type") val tokenType: String,
)

@Serializable
data class APIToken(
    val id: Int,
    val name: String,
    val createdAt: String? = null,
)

@Serializable
data class AppInfo(
    val version: String,
    val demoStatus: Boolean? = null,
    val allowSignup: Boolean? = null,
    val enableOidc: Boolean? = null,
)
