package com.jackabee.mealie.di

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.room.Room
import com.jackabee.mealie.data.api.MealieApi
import com.jackabee.mealie.data.api.MealieClient
import com.jackabee.mealie.data.auth.AndroidKeystoreSecretStore
import com.jackabee.mealie.data.auth.SecureKeyValueStore
import com.jackabee.mealie.data.auth.AuthStore
import com.jackabee.mealie.data.auth.SharedPrefsKeyValueStore
import com.jackabee.mealie.data.model.MealieJson
import com.jackabee.mealie.data.parser.RecipeUrlParser
import com.jackabee.mealie.data.repository.AuthRepository
import com.jackabee.mealie.data.repository.MealPlanRepository
import com.jackabee.mealie.data.repository.RecipeRepository
import com.jackabee.mealie.data.repository.ShoppingRepository
import com.jackabee.mealie.data.settings.AppSettings
import com.jackabee.mealie.data.store.CacheService
import com.jackabee.mealie.data.store.LocalGroceryStore
import com.jackabee.mealie.data.store.LocalRecipeStore
import com.jackabee.mealie.data.store.MealieDatabase
import com.jackabee.mealie.data.store.OfflineRecipeStore
import com.jackabee.mealie.data.store.RecipeSyncService
import java.io.File

/**
 * Simple manual dependency container (no Hilt), constructed once in
 * [com.jackabee.mealie.MealieApplication].
 */
class AppContainer(context: Context) {

    private val appContext = context.applicationContext

    val json = MealieJson

    val client = MealieClient()
    val api = MealieApi(client, json)

    val keyValueStore = SecureKeyValueStore(SharedPrefsKeyValueStore(appContext), AndroidKeystoreSecretStore(appContext))
    val authStore = AuthStore(keyValueStore, json, client)
    val settings = AppSettings(keyValueStore)

    val cache = CacheService(File(appContext.cacheDir, "mealie_cache"), json)

    private val database: MealieDatabase = Room.databaseBuilder(
        appContext,
        MealieDatabase::class.java,
        "mealie.db",
    ).build()

    val localRecipeStore = LocalRecipeStore(
        dao = database.localRecipeDao(),
        kv = keyValueStore,
        json = json,
        filesRoot = appContext.filesDir,
    )

    val offlineRecipeStore = OfflineRecipeStore(appContext.filesDir, keyValueStore, json)
    val localGroceryStore = LocalGroceryStore(keyValueStore, json)
    val recipeSyncService = RecipeSyncService(appContext.filesDir, keyValueStore, api, json)
    val recipeUrlParser = RecipeUrlParser(localRecipeStore = localRecipeStore)

    val authRepository = AuthRepository(api, authStore)
    val recipeRepository = RecipeRepository(
        api = api,
        syncService = recipeSyncService,
        localStore = localRecipeStore,
        offlineStore = offlineRecipeStore,
        cache = cache,
        urlParser = recipeUrlParser,
    )
    val mealPlanRepository = MealPlanRepository(api, cache)
    val shoppingRepository = ShoppingRepository(api, cache, localGroceryStore)

    /** Set by the UI layer to react to soft logout (hopped to the main thread here). */
    var onUnauthorized: (() -> Unit)? = null

    init {
        client.credentialsProvider = authStore
        client.onUnauthorized = {
            Handler(Looper.getMainLooper()).post {
                authStore.softClearSession()
                onUnauthorized?.invoke()
            }
        }
    }
}
