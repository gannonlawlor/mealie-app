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
import com.jackabee.mealie.di.AppContainer
import com.jackabee.mealie.ui.navigation.AppRoot
import com.jackabee.mealie.ui.screens.common.ThemeController
import com.jackabee.mealie.ui.theme.MealieTheme
import com.jackabee.mealie.ui.viewmodel.AuthViewModel
import com.jackabee.mealie.ui.viewmodel.MealPlanViewModel
import com.jackabee.mealie.ui.viewmodel.RecipeViewModel
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel
import kotlinx.coroutines.flow.MutableStateFlow

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

    /** Persist every shared link before the authenticated UI starts processing it. */
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

        container.authStore.queuePendingImportURL(url)
        importEvents.value += 1
    }

    private fun extractFirstUrl(text: String): String? =
        Regex("""https?://\S+""").find(text)?.value
}
