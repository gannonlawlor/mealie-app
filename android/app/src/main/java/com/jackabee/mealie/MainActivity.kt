package com.jackabee.mealie

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.lifecycle.lifecycleScope
import com.jackabee.mealie.data.auth.AppMode
import com.jackabee.mealie.di.AppContainer
import com.jackabee.mealie.ui.navigation.AppRoot
import com.jackabee.mealie.ui.screens.common.ThemeController
import com.jackabee.mealie.ui.theme.MealieTheme
import com.jackabee.mealie.ui.viewmodel.AuthViewModel
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private val container: AppContainer
        get() = (application as MealieApplication).container

    private val authViewModel: AuthViewModel by viewModels { AuthViewModel.factory(container) }
    private val recipeViewModel: RecipeViewModel by viewModels { RecipeViewModel.factory(container) }
    private val mealPlanViewModel: MealPlanViewModel by viewModels { MealPlanViewModel.factory(container) }
    private val shoppingViewModel: ShoppingViewModel by viewModels { ShoppingViewModel.factory(container) }

    /** Bumped whenever a share/view import intent arrives so the UI switches to Recipes. */
    private val importEvents = MutableStateFlow(0L)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // The store-level soft clear is wired in AppContainer; make the VM state follow.
        container.onUnauthorized = { authViewModel.softLogout() }

        ThemeController.theme = container.settings.theme

        // Only handle the launch intent on a fresh start, not on recreation.
        if (savedInstanceState == null) {
            handleImportIntent(intent)
        }

        setContent {
            MealieTheme(themePreference = ThemeController.theme) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    AppRoot(
                        container = container,
                        authViewModel = authViewModel,
                        recipeViewModel = recipeViewModel,
                        mealPlanViewModel = mealPlanViewModel,
                        shoppingViewModel = shoppingViewModel,
                        importEvents = importEvents,
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleImportIntent(intent)
    }

    /**
     * Handles ACTION_SEND (shared text containing a recipe URL) and ACTION_VIEW
     * (opened http/https link) — the Android counterpart of the iOS `onOpenURL`
     * / share-extension flow. Imports immediately when a session is usable
     * (local mode or restored server session); otherwise queues the URL on
     * AuthStore for the AppRoot drain after authentication, with no failure
     * banner — the recipes screen stays silent until the drain runs.
     */
    private fun handleImportIntent(intent: Intent?) {
        intent ?: return
        val url = when (intent.action) {
            Intent.ACTION_SEND ->
                if (intent.type == "text/plain") {
                    extractFirstUrl(intent.getStringExtra(Intent.EXTRA_TEXT).orEmpty())
                } else {
                    null
                }
            Intent.ACTION_VIEW -> intent.data?.toString()
            else -> null
        }
        if (url.isNullOrEmpty()) return

        val authStore = container.authStore
        if (authStore.savedAppMode == AppMode.LOCAL) {
            recipeViewModel.setLocalMode(true)
            recipeViewModel.updateImportURL(url)
            lifecycleScope.launch { recipeViewModel.importFromURL() }
            importEvents.value += 1
            return
        }
        if (authStore.restoreSession()) {
            recipeViewModel.updateImportURL(url)
            lifecycleScope.launch { recipeViewModel.importFromURL() }
            importEvents.value += 1
            return
        }
        authStore.queuePendingImportURL(url)
        importEvents.value += 1
    }

    private fun extractFirstUrl(text: String): String? =
        Regex("""https?://\S+""").find(text)?.value
}
