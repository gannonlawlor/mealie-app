package com.jackabee.mealie.screenshots

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import com.jackabee.mealie.data.model.ShoppingListPaginatedResponse
import com.jackabee.mealie.data.model.User
import com.jackabee.mealie.ui.screens.settings.SettingsScreen
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel7)
class SettingsScreenshotTest {

    @get:Rule
    val composeRule = createComposeRule()

    @get:Rule
    val tmp = TemporaryFolder()

    @Test
    fun settings_localMode() {
        val env = ScreenshotEnv(tmp.root)
        env.authViewModel.enterLocalMode()

        composeRule.setContent {
            ScreenshotTheme {
                SettingsScreen(
                    authViewModel = env.authViewModel,
                    shoppingViewModel = env.shoppingViewModel,
                )
            }
        }

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/Settings_localMode.png")
    }

    /**
     * Server-connected variant: covers the "Shopping Lists" section with the
     * Default Shopping List dropdown (showing a selected default) and the
     * Queue Items Locally toggle, plus the Profile and Server sections.
     */
    @Test
    fun settings_serverMode_withDefaultList() {
        val env = ScreenshotEnv(tmp.root)
        env.api.currentUserHandler = {
            User(id = "user-1", username = "chef", fullName = "Chef Example", email = "chef@example.com")
        }
        env.api.getShoppingListsHandler = {
            ShoppingListPaginatedResponse(
                items = listOf(ScreenshotFixtures.groceriesList(), ScreenshotFixtures.farmersMarketList()),
            )
        }
        env.authViewModel.updateServerURL("https://demo.mealie.example")
        runBlocking {
            env.authViewModel.validateServer()
            env.authViewModel.updateEmail("chef@example.com")
            env.authViewModel.updatePassword("super-secret")
            env.authViewModel.login()
            env.shoppingViewModel.loadShoppingLists()
        }

        // The screen reads the default-list preference and server URL from the
        // app container (Robolectric in-memory prefs) — set before composing.
        appContainer().settings.defaultShoppingListId = ScreenshotFixtures.GROCERIES_LIST_ID
        appContainer().settings.defaultShoppingListName = "Groceries"
        appContainer().authStore.savedServerURL = "https://demo.mealie.example"

        composeRule.setContent {
            ScreenshotTheme {
                SettingsScreen(
                    authViewModel = env.authViewModel,
                    shoppingViewModel = env.shoppingViewModel,
                )
            }
        }

        composeRule.onRoot().captureRoboImage("$SNAPSHOT_DIR/Settings_serverMode.png")
    }
}
