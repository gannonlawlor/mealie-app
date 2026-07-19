package com.jackabee.mealie.data.model

import kotlinx.serialization.Serializable

@Serializable
data class User(
    val id: String,
    val username: String? = null,
    val fullName: String? = null,
    val email: String? = null,
    val admin: Boolean? = null,
    val group: String? = null,
    val household: String? = null,
    val groupId: String? = null,
    val householdId: String? = null,
    val tokens: List<APIToken>? = null,
    val canInvite: Boolean? = null,
    val canManage: Boolean? = null,
    val canOrganize: Boolean? = null,
    val favoriteRecipes: List<String>? = null,
)

@Serializable
data class UserFavorites(
    val favoriteRecipes: List<String>? = null,
)
